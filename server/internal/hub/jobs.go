package hub

import (
	"net"
	"net/http"
	"slices"
	"sort"
	"strconv"
	"strings"
	"time"

	"github.com/google/uuid"
	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/store"
)

// Jobs: processes an agent starts and supervises for the hub. The hub keeps
// the list, a tail of each one's output, and resolves secrets for them from
// the project's sealed files. See docs/architecture/jobs.md.

const (
	jobLogLines    = 2000
	defaultJobTail = 200
	maxJobCommand  = 8 << 10
)

var errJobNotFound = &opError{"not_found", "unknown job", http.StatusNotFound}

func jobLive(st v1.JobState) bool {
	switch st {
	case v1.JobState_JOB_STATE_STARTING, v1.JobState_JOB_STATE_RUNNING, v1.JobState_JOB_STATE_PAUSED:
		return true
	}
	return false
}

func (h *Hub) loadJobs() error {
	list, err := h.store.Jobs()
	if err != nil {
		return err
	}
	for _, j := range list {
		h.jobs[j.Id] = j
	}
	return nil
}

func (h *Hub) jobRoutes(mux *http.ServeMux) {
	mux.HandleFunc("GET /api/v1/jobs", h.api(func(r *http.Request) (proto.Message, *opError) {
		return h.jobList(r.URL.Query().Get("node")), nil
	}))
	mux.HandleFunc("POST /api/v1/jobs", h.api(func(r *http.Request) (proto.Message, *opError) {
		spec := &v1.JobSpec{}
		if err := decode(r, spec); err != nil {
			return nil, err
		}
		return h.startJob(spec, clientName(r))
	}))
	mux.HandleFunc("POST /api/v1/jobs/{id}/{action}", h.api(func(r *http.Request) (proto.Message, *opError) {
		return h.jobAction(r.PathValue("id"), r.PathValue("action"), clientName(r))
	}))
	mux.HandleFunc("DELETE /api/v1/jobs/{id}", h.api(func(r *http.Request) (proto.Message, *opError) {
		return ackOf("", h.forgetJob(r.PathValue("id")))
	}))
	mux.HandleFunc("GET /api/v1/jobs/{id}/logs", h.api(func(r *http.Request) (proto.Message, *opError) {
		n, _ := strconv.Atoi(r.URL.Query().Get("tail"))
		return h.jobTail(r.PathValue("id"), n)
	}))
}

// jobList is the jobs, newest first. Caller holds h.mu.
func (h *Hub) jobList(node string) *v1.JobList {
	out := &v1.JobList{}
	for _, j := range h.jobs {
		if node == "" || j.Spec.GetNode() == node {
			out.Jobs = append(out.Jobs, proto.Clone(j).(*v1.Job))
		}
	}
	sort.Slice(out.Jobs, func(i, k int) bool { return out.Jobs[i].CreatedMs > out.Jobs[k].CreatedMs })
	return out
}

// startJob checks a spec, picks a GPU machine for one that needs it and
// names none, and asks the node to start it. Caller holds h.mu.
func (h *Hub) startJob(spec *v1.JobSpec, by string) (*v1.Job, *opError) {
	spec.Command, spec.Cwd, spec.Node = strings.TrimSpace(spec.Command), strings.TrimSpace(spec.Cwd), strings.TrimSpace(spec.Node)
	switch {
	case spec.Command == "" || len(spec.Command) > maxJobCommand:
		return nil, invalid("a job needs a command")
	case spec.Cwd == "":
		return nil, invalid("a job needs a folder to run in")
	case spec.Port < 0 || spec.Port > 65535:
		return nil, invalid("the port must be between 1 and 65535")
	}
	switch spec.Restart {
	case "", "never", "on-failure", "always":
	default:
		return nil, invalid("restart must be never, on-failure or always")
	}
	if spec.Node == "" && spec.NeedsGpu {
		spec.Node = h.gpuNode()
		if spec.Node == "" {
			return nil, &opError{"node_offline", "no machine with a GPU is online", http.StatusServiceUnavailable}
		}
	}
	if spec.Node == "" {
		return nil, invalid("a job needs a device")
	}
	if spec.NeedsGpu && !nodeHasGPU(h.nodes[spec.Node]) {
		return nil, invalid(spec.Node + " has no GPU Tether can see; pick a machine with one")
	}
	if spec.Name == "" {
		spec.Name = clip(spec.Command, 40)
	}
	for _, ref := range spec.EnvFrom {
		if ref.Repo == "" {
			ref.Repo = repoName(spec.Node, spec.Cwd)
		}
	}
	now := time.Now().UnixMilli()
	j := &v1.Job{Id: uuid.NewString()[:8], Spec: spec, State: v1.JobState_JOB_STATE_STARTING, CreatedMs: now, UpdatedMs: now, By: by}
	if err := h.sendJob(j, "start"); err != nil {
		return nil, err
	}
	h.putJob(j)
	h.audit(by, "job", j.Id, "started on "+spec.Node+": "+clip(spec.Command, 80), true)
	return proto.Clone(j).(*v1.Job), nil
}

// sendJob sends a job command to the job's node, with the secrets it
// needs for a start. Caller holds h.mu.
func (h *Hub) sendJob(j *v1.Job, action string) *opError {
	node := j.Spec.GetNode()
	conn := h.agents[node]
	if conn == nil {
		return errNodeOffline
	}
	if !h.jobNodes[node] {
		return &opError{"unsupported", node + "'s agent is too old to run jobs; update it", http.StatusConflict}
	}
	c := &v1.AgentCommand_JobCommand{Id: j.Id, Action: action}
	if action == "start" || action == "restart" {
		secret, err := h.jobSecrets(j.Spec)
		if err != nil {
			return err
		}
		c.Spec, c.SecretEnv = j.Spec, secret
	}
	conn.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_Job{Job: c}}))
	return nil
}

// jobSecrets reads the keys a job takes from its project's sealed files.
// The node must be one the owner allowed for the project, or the device
// the project is on. Caller holds h.mu.
func (h *Hub) jobSecrets(spec *v1.JobSpec) (map[string]string, *opError) {
	if len(spec.EnvFrom) == 0 {
		return nil, nil
	}
	key, err := h.secretsKey()
	if err != nil {
		return nil, &opError{"internal", "the vault could not do that", http.StatusInternalServerError}
	}
	gcm, err := newGCM(key)
	if err != nil {
		return nil, &opError{"internal", "the vault could not do that", http.StatusInternalServerError}
	}
	out := map[string]string{}
	for _, ref := range spec.EnvFrom {
		path, ok := cleanProjectPath(ref.File)
		if !repoID.MatchString(ref.Repo) || !ok {
			return nil, invalid("a secret reference needs a project and a file in it")
		}
		nodes, err := h.store.ProjectNodes(ref.Repo)
		if err != nil {
			return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
		}
		if !slices.Contains(nodes, spec.Node) && repoName(spec.Node, spec.Cwd) != ref.Repo {
			return nil, &opError{"forbidden", spec.Node + " is not allowed to receive " + ref.Repo + "'s files", http.StatusForbidden}
		}
		files, err := h.store.ProjectFiles(ref.Repo)
		if err != nil {
			return nil, &opError{"internal", err.Error(), http.StatusInternalServerError}
		}
		found := false
		for _, f := range files {
			if f.Path != path {
				continue
			}
			plain, err := gcm.Open(nil, f.Nonce, f.Sealed, []byte(ref.Repo+"/"+f.Path))
			if err != nil {
				return nil, &opError{"internal", "the vault could not open " + path, http.StatusInternalServerError}
			}
			values := envValues(string(plain))
			for _, k := range ref.Keys {
				if _, ok := values[k]; !ok {
					return nil, invalid(path + " has no key " + k)
				}
			}
			for k, v := range values {
				if len(ref.Keys) == 0 || slices.Contains(ref.Keys, k) {
					out[k] = v
				}
			}
			found = true
		}
		if !found {
			return nil, invalid("the project has no sealed file " + path)
		}
	}
	return out, nil
}

// envValues reads KEY=value lines, without surrounding quotes.
func envValues(content string) map[string]string {
	out := map[string]string{}
	for _, line := range strings.Split(content, "\n") {
		m := envLine.FindStringSubmatch(strings.TrimRight(line, "\r"))
		if m == nil || strings.HasPrefix(strings.TrimSpace(line), "#") {
			continue
		}
		v := strings.TrimSpace(m[2])
		if len(v) >= 2 && (v[0] == '"' && v[len(v)-1] == '"' || v[0] == '\'' && v[len(v)-1] == '\'') {
			v = v[1 : len(v)-1]
		}
		out[m[1]] = v
	}
	return out
}

// jobAction stops, pauses, resumes or restarts a job. Caller holds h.mu.
func (h *Hub) jobAction(id, action, by string) (*v1.Job, *opError) {
	j := h.jobs[id]
	if j == nil {
		return nil, errJobNotFound
	}
	switch action {
	case "stop", "pause", "resume":
		if !jobLive(j.State) {
			return nil, &opError{"invalid", "the job is not running", http.StatusConflict}
		}
	case "restart":
	default:
		return nil, invalid("unknown action " + action)
	}
	if err := h.sendJob(j, action); err != nil {
		return nil, err
	}
	h.audit(by, "job", id, action, true)
	return proto.Clone(j).(*v1.Job), nil
}

// forgetJob drops an ended job here and on its node. Caller holds h.mu.
func (h *Hub) forgetJob(id string) *opError {
	j := h.jobs[id]
	if j == nil {
		return errJobNotFound
	}
	if jobLive(j.State) {
		return &opError{"invalid", "stop the job first", http.StatusConflict}
	}
	if conn := h.agents[j.Spec.GetNode()]; conn != nil && h.jobNodes[j.Spec.GetNode()] {
		conn.Send(command(&v1.AgentCommand{Op: &v1.AgentCommand_Job{Job: &v1.AgentCommand_JobCommand{Id: id, Action: "forget"}}}))
	}
	delete(h.jobs, id)
	delete(h.jobLogs, id)
	if err := h.store.DeleteJob(id); err != nil {
		h.log.Error("delete job", "job", id, "err", err)
	}
	gone := proto.Clone(j).(*v1.Job)
	gone.Spec = nil
	h.broadcast(&v1.Frame{Body: &v1.Frame_Job{Job: gone}})
	return nil
}

// jobTail is the last n lines the hub has of a job's output. Caller holds h.mu.
func (h *Hub) jobTail(id string, n int) (*v1.JobLogTail, *opError) {
	if h.jobs[id] == nil {
		return nil, errJobNotFound
	}
	if n <= 0 {
		n = defaultJobTail
	}
	lines := h.jobLogs[id]
	return &v1.JobLogTail{Job: id, Lines: slices.Clone(lines[max(0, len(lines)-n):])}, nil
}

// noteJobReport takes in what an agent says of its jobs. Caller holds h.mu.
func (h *Hub) noteJobReport(node string, r *v1.JobReport) {
	h.jobNodes[node] = true
	seen := map[string]bool{}
	for _, in := range r.Jobs {
		seen[in.Id] = true
		cur := h.jobs[in.Id]
		if cur != nil && cur.Spec.GetNode() != node {
			continue
		}
		if in.Spec == nil && cur != nil {
			in.Spec = cur.Spec
		}
		if in.Spec == nil {
			in.Spec = &v1.JobSpec{}
		}
		in.Spec.Node = node
		if cur != nil {
			in.By = cur.By
			// Only the hub knows which project a reference was resolved in.
			in.Spec.EnvFrom = cur.Spec.GetEnvFrom()
			if in.CreatedMs == 0 {
				in.CreatedMs = cur.CreatedMs
			}
		}
		h.putJob(in)
	}
	if !r.Full {
		return
	}
	for id, j := range h.jobs {
		if j.Spec.GetNode() == node && !seen[id] && jobLive(j.State) {
			n := proto.Clone(j).(*v1.Job)
			n.State, n.Error, n.EndedMs = v1.JobState_JOB_STATE_LOST, "its device no longer has it", time.Now().UnixMilli()
			h.putJob(n)
		}
	}
}

// noteJobLog keeps the newest lines of a job's output. Caller holds h.mu.
func (h *Hub) noteJobLog(node string, l *v1.JobLog) {
	if j := h.jobs[l.Job]; j == nil || j.Spec.GetNode() != node {
		return
	}
	lines := h.jobLogs[l.Job]
	if l.Replace {
		lines = nil
	}
	lines = append(lines, l.Lines...)
	if over := len(lines) - jobLogLines; over > 0 {
		lines = slices.Clone(lines[over:])
	}
	h.jobLogs[l.Job] = lines
}

// putJob stores a job and tells every app. Caller holds h.mu.
func (h *Hub) putJob(j *v1.Job) {
	j.Address = ""
	if p := j.Spec.GetPort(); p > 0 {
		if host := h.nodeHost(j.Spec.Node); host != "" {
			j.Address = "http://" + net.JoinHostPort(host, strconv.Itoa(int(p)))
		}
	}
	if j.UpdatedMs == 0 {
		j.UpdatedMs = time.Now().UnixMilli()
	}
	h.jobs[j.Id] = j
	if err := h.store.PutJob(j); err != nil {
		h.log.Error("store job", "job", j.Id, "err", err)
	}
	h.broadcast(&v1.Frame{Body: &v1.Frame_Job{Job: proto.Clone(j).(*v1.Job)}})
}

// nodeHost is the name a node is reached by on the tailnet: its MagicDNS
// name when the hub has read tailscale status, else the address its agent
// connects from. Caller holds h.mu.
func (h *Hub) nodeHost(node string) string {
	ip := h.agentIPs[node]
	local := ip != "" && localIP(ip)
	if h.tsMu.TryLock() {
		st := h.tsStatus
		h.tsMu.Unlock()
		if st == nil {
			go h.ownDevice("")
		} else {
			if st.Self != nil && local {
				if name := strings.TrimSuffix(st.Self.DNSName, "."); name != "" {
					return name
				}
				if len(st.Self.TailscaleIPs) > 0 {
					return st.Self.TailscaleIPs[0]
				}
			}
			for _, p := range st.Peer {
				if slices.Contains(p.TailscaleIPs, ip) {
					if name := strings.TrimSuffix(p.DNSName, "."); name != "" {
						return name
					}
				}
			}
		}
	}
	if local {
		return ""
	}
	return ip
}

func nodeHasGPU(n *v1.NodeStatus) bool {
	return n != nil && slices.Contains(n.Capabilities, "gpu")
}

// gpuNode is an online machine with a GPU, the one running fewest jobs
// first. Caller holds h.mu.
func (h *Hub) gpuNode() string {
	running := map[string]int{}
	for _, j := range h.jobs {
		if jobLive(j.State) {
			running[j.Spec.GetNode()]++
		}
	}
	best := ""
	for name, n := range h.nodes {
		if h.agents[name] == nil || !nodeHasGPU(n) {
			continue
		}
		if best == "" || running[name] < running[best] || running[name] == running[best] && name < best {
			best = name
		}
	}
	return best
}

func jobStateName(st v1.JobState) string { return store.JobStateName(st) }
