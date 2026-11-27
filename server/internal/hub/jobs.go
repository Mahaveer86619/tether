package hub

import (
	"context"
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
		return h.jobList(userOf(r), r.URL.Query().Get("node")), nil
	}))
	mux.HandleFunc("POST /api/v1/jobs", h.api(func(r *http.Request) (proto.Message, *opError) {
		spec := &v1.JobSpec{}
		if err := decode(r, spec); err != nil {
			return nil, err
		}
		return h.startJob(userOf(r), spec, clientName(r))
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

// jobList is the jobs id may see, newest first. Caller holds h.mu.
func (h *Hub) jobList(id identity, node string) *v1.JobList {
	out := &v1.JobList{}
	for _, j := range h.jobs {
		if (node == "" || j.Spec.GetNode() == node) && h.can(id, actView, objJob, j.Id) {
			out.Jobs = append(out.Jobs, proto.Clone(j).(*v1.Job))
		}
	}
	sort.Slice(out.Jobs, func(i, k int) bool { return out.Jobs[i].CreatedMs > out.Jobs[k].CreatedMs })
	return out
}

// startJob checks a spec, picks a GPU machine for one that needs it and
// names none, and asks the node to start it. Caller holds h.mu.
func (h *Hub) startJob(as identity, spec *v1.JobSpec, by string) (*v1.Job, *opError) {
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
	if !h.can(as, actRunJob, objNode, spec.Node) {
		return nil, errForbidden
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
	schedule := spec.GetSchedule()
	var slot *v1.DeviceSlot
	if schedule != "" && schedule != "now" && schedule != "next_free" {
		slot = h.slotByID(spec.Node, schedule)
		if slot == nil {
			return nil, &opError{"not_found", "unknown slot: " + schedule, http.StatusNotFound}
		}
		if slot.User != as.userID() && !as.root() {
			return nil, errForbidden
		}
	}
	nowTime := time.Now()
	now := nowTime.UnixMilli()
	canRunNow, reason := h.canUseDeviceNow(as, actRunJob, spec.Node, nowTime)
	if slot != nil && (now < slot.StartMs || now >= slot.EndMs) {
		canRunNow, reason = false, "slot_not_active"
	}
	wantsQueue := spec.GetQueueWhenBusy() || schedule == "next_free" || slot != nil
	if !canRunNow && !wantsQueue {
		switch reason {
		case "outside_window":
			return nil, &opError{"device_window_closed", "this device is currently outside your allowed sharing window", http.StatusForbidden}
		case "slot_conflict":
			return nil, &opError{"slot_conflict", "this device is reserved by another teammate's slot right now", http.StatusConflict}
		case "slot_not_active":
			return nil, &opError{"slot_not_active", "your booked slot for this job has not started", http.StatusConflict}
		default:
			return nil, errForbidden
		}
	}
	queueIt := !canRunNow
	owner := firstNonEmpty(as.userID(), h.ownerID)
	if queueIt {
		j := &v1.Job{Id: uuid.NewString()[:8], Spec: spec, State: v1.JobState_JOB_STATE_QUEUED, CreatedMs: now, UpdatedMs: now, By: by, Owner: owner}
		h.putJob(j)
		h.audit(by, "job", j.Id, "queued on "+spec.Node+": "+clip(spec.Command, 80)+" ("+reason+")", true)
		return proto.Clone(j).(*v1.Job), nil
	}

	j := &v1.Job{Id: uuid.NewString()[:8], Spec: spec, State: v1.JobState_JOB_STATE_STARTING, CreatedMs: now, UpdatedMs: now, By: by, Owner: owner}
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
	case "stop":
		if j.State == v1.JobState_JOB_STATE_QUEUED {
			j.State = v1.JobState_JOB_STATE_STOPPED
			j.UpdatedMs = time.Now().UnixMilli()
			h.putJob(j)
			h.audit(by, "job", id, "stopped", true)
			return proto.Clone(j).(*v1.Job), nil
		}
		if !jobLive(j.State) {
			return nil, &opError{"invalid", "the job is not running", http.StatusConflict}
		}
	case "pause", "resume":
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
	if jobLive(j.State) || j.State == v1.JobState_JOB_STATE_QUEUED {
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
			if in.Owner == "" {
				in.Owner = cur.Owner
			}
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

const jobScheduleEvery = 15 * time.Second

func (h *Hub) jobScheduleLoop(ctx context.Context) {
	t := time.NewTicker(jobScheduleEvery)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case now := <-t.C:
			h.mu.Lock()
			h.scheduleJobs(now)
			h.mu.Unlock()
		}
	}
}

// jobWantsAutoResume reports whether a paused job may be picked up again when
// its device becomes free.
func jobWantsAutoResume(j *v1.Job) bool {
	s := j.Spec.GetSchedule()
	return j.Spec.GetQueueWhenBusy() || s == "next_free" || (s != "" && s != "now")
}

// jobAwaitingSchedule reports whether a job is waiting for its window to open.
func jobAwaitingSchedule(j *v1.Job) bool {
	return j.State == v1.JobState_JOB_STATE_QUEUED ||
		(j.State == v1.JobState_JOB_STATE_PAUSED && jobWantsAutoResume(j))
}

// jobSlotReady reports whether a job tied to a booked slot may run at now.
// A cancelled slot leaves the job queued rather than running early. Caller holds h.mu.
func (h *Hub) jobSlotReady(j *v1.Job, now time.Time) bool {
	s := j.Spec.GetSchedule()
	if s == "" || s == "now" || s == "next_free" {
		return true
	}
	slot := h.slotByID(j.Spec.GetNode(), s)
	return slot != nil && now.UnixMilli() >= slot.StartMs && now.UnixMilli() < slot.EndMs
}

// scheduleJobs performs smart free-time allocation:
// 1. Dispatches queued jobs when off-peak window opens or a booked slot becomes active.
// 2. Pauses running non-owner jobs when off-peak window closes or another user's booked slot begins.
// Caller holds h.mu.
func (h *Hub) scheduleJobs(now time.Time) {
	// 1. Check running non-owner jobs: pause them if their window closed or a slot conflict arose.
	for _, j := range h.jobs {
		if j.State != v1.JobState_JOB_STATE_RUNNING && j.State != v1.JobState_JOB_STATE_STARTING {
			continue
		}
		node := j.Spec.GetNode()
		owner := h.nodeOwner(node)
		if j.Owner == owner || j.Owner == h.ownerID {
			continue
		}
		canRun, reason := h.canUseDeviceNow(h.asUser(j.Owner), actRunJob, node, now)
		if canRun && !h.jobSlotReady(j, now) {
			canRun, reason = false, "slot_not_active"
		}
		if !canRun {
			_ = h.sendJob(j, "pause")
			j.State = v1.JobState_JOB_STATE_PAUSED
			j.UpdatedMs = now.UnixMilli()
			h.putJob(j)
			h.audit("scheduler", "job", j.Id, "paused non-owner job ("+reason+") to free device for owner", true)
		}
	}

	// 2. Collect queued or auto-paused jobs that can now run
	var candidates []*v1.Job
	for _, j := range h.jobs {
		if jobAwaitingSchedule(j) {
			candidates = append(candidates, j)
		}
	}
	sort.Slice(candidates, func(i, k int) bool { return candidates[i].CreatedMs < candidates[k].CreatedMs })

	// A paused job waiting for its window does not hold the device; other live jobs do.
	nodeBusy := map[string]bool{}
	for _, j := range h.jobs {
		if jobAwaitingSchedule(j) {
			continue
		}
		if jobLive(j.State) {
			nodeBusy[j.Spec.GetNode()] = true
		}
	}

	for _, j := range candidates {
		node := j.Spec.GetNode()
		if h.agents[node] == nil || !h.jobNodes[node] {
			continue
		}
		if nodeBusy[node] {
			continue
		}
		canRun, _ := h.canUseDeviceNow(h.asUser(j.Owner), actRunJob, node, now)
		if !canRun || !h.jobSlotReady(j, now) {
			continue
		}
		action := "start"
		if j.State == v1.JobState_JOB_STATE_PAUSED {
			action = "resume"
		}
		if err := h.sendJob(j, action); err != nil {
			j.State = v1.JobState_JOB_STATE_FAILED
			j.Error = err.Error()
			j.UpdatedMs = now.UnixMilli()
			h.putJob(j)
			continue
		}
		j.State = v1.JobState_JOB_STATE_STARTING
		if j.StartedMs == 0 {
			j.StartedMs = now.UnixMilli()
		}
		j.UpdatedMs = now.UnixMilli()
		h.putJob(j)
		nodeBusy[node] = true
		h.audit("scheduler", "job", j.Id, "dispatched queued job on "+node, true)
	}
}
