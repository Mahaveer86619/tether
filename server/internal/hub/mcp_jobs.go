package hub

import (
	"fmt"
	"strings"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

var jobTools = []mcpTool{
	{
		Name: "start_job",
		Description: "Start a job: a server, script or training run that a machine's agent runs and supervises, outside any session. " +
			"It keeps running when this session ends. Returns the job id; follow it with job_status and job_logs.",
		InputSchema: schema([]string{"command", "cwd"}, map[string]string{
			"command":      "string: the command, run by the machine's shell",
			"cwd":          "string: the folder on that machine",
			"node":         "string: the machine, as list_nodes names it; omit with needs_gpu to pick one with a GPU",
			"name":         "string: a short name to show",
			"port":         "integer: the port a server listens on; the user gets a link to it on the tailnet",
			"restart":      "string: never (default), on-failure or always",
			"needs_gpu":    "boolean: run it on a machine with a GPU",
			"secrets_from": "string: a sealed setup file of the project in cwd (e.g. .env) whose keys go into the job's environment",
			"checkpoint":   "string: a command run before a stop so the job can save its state",
		}),
		call: (*Hub).mcpStartJob,
	},
	{
		Name:        "job_status",
		Description: "Jobs and their state (starting, running, paused, exited, failed, stopped, lost), exit code, error and address. Without id, every job.",
		InputSchema: schema(nil, map[string]string{"id": "string: one job", "node": "string: only this machine's jobs"}),
		call:        (*Hub).mcpJobStatus,
	},
	{
		Name:        "job_logs",
		Description: "The last lines of a job's output.",
		InputSchema: schema([]string{"id"}, map[string]string{"id": "string: the job", "tail": "integer: how many lines (default 200, at most 2000)"}),
		call:        (*Hub).mcpJobLogs,
	},
	{
		Name:        "stop_job",
		Description: "Stop a job: its checkpoint command first if it has one, then a polite signal, then a kill after a grace period. The job's child processes end with it.",
		InputSchema: schema([]string{"id"}, map[string]string{"id": "string: the job"}),
		call:        jobActionTool("stop"),
	},
	{
		Name:        "pause_job",
		Description: "Pause a job: every process of it is suspended. Its memory, and a GPU's, stays held, and network peers may time out. Resume with resume_job.",
		InputSchema: schema([]string{"id"}, map[string]string{"id": "string: the job"}),
		call:        jobActionTool("pause"),
	},
	{
		Name:        "resume_job",
		Description: "Resume a paused job.",
		InputSchema: schema([]string{"id"}, map[string]string{"id": "string: the job"}),
		call:        jobActionTool("resume"),
	},
}

func init() { mcpTools = append(mcpTools, jobTools...) }

func (h *Hub) mcpStartJob(caller identity, args map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	spec := &v1.JobSpec{Command: str(args, "command"), Cwd: str(args, "cwd"), Node: str(args, "node"), Name: str(args, "name"),
		Port: int32(num(args, "port", 0)), Restart: str(args, "restart"), NeedsGpu: args["needs_gpu"] == true, Checkpoint: str(args, "checkpoint")}
	if f := str(args, "secrets_from"); f != "" {
		spec.EnvFrom = []*v1.EnvRef{{File: f}}
	}
	j, err := h.startJob(caller, spec, mcpSource)
	if err != nil {
		return "", opErr(err)
	}
	return fmt.Sprintf("Started job %s on %s. Check it with job_status and job_logs.", j.Id, j.Spec.Node), nil
}

func (h *Hub) mcpJobStatus(caller identity, args map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	id := str(args, "id")
	if id != "" && !h.can(caller, actView, objJob, id) {
		return "", fmt.Errorf("unknown job %s", id)
	}
	var out []map[string]any
	for _, j := range h.jobList(caller, str(args, "node")).Jobs {
		if id != "" && j.Id != id {
			continue
		}
		m := map[string]any{"id": j.Id, "name": j.Spec.Name, "node": j.Spec.Node, "cwd": j.Spec.Cwd, "command": j.Spec.Command,
			"state": jobStateName(j.State), "restarts": j.Restarts}
		if j.StartedMs > 0 {
			m["started"] = time.UnixMilli(j.StartedMs).Format(time.RFC3339)
		}
		if j.EndedMs > 0 {
			m["ended"], m["exit_code"] = time.UnixMilli(j.EndedMs).Format(time.RFC3339), j.ExitCode
		}
		if j.Error != "" {
			m["error"] = j.Error
		}
		if j.Address != "" {
			m["address"] = j.Address
		}
		out = append(out, m)
	}
	if len(out) == 0 {
		return "No jobs.", nil
	}
	return jsonText(out)
}

func (h *Hub) mcpJobLogs(caller identity, args map[string]any) (string, error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if !h.can(caller, actView, objJob, str(args, "id")) {
		return "", fmt.Errorf("unknown job %s", str(args, "id"))
	}
	t, err := h.jobTail(str(args, "id"), min(num(args, "tail", defaultJobTail), jobLogLines))
	if err != nil {
		return "", opErr(err)
	}
	if len(t.Lines) == 0 {
		return "No output yet.", nil
	}
	return strings.Join(t.Lines, "\n"), nil
}

func jobActionTool(action string) func(*Hub, identity, map[string]any) (string, error) {
	return func(h *Hub, caller identity, args map[string]any) (string, error) {
		h.mu.Lock()
		defer h.mu.Unlock()
		if !h.can(caller, actStop, objJob, str(args, "id")) {
			return "", fmt.Errorf("unknown job %s", str(args, "id"))
		}
		j, err := h.jobAction(str(args, "id"), action, mcpSource)
		if err != nil {
			return "", opErr(err)
		}
		return fmt.Sprintf("Asked %s to %s job %s; job_status shows when it has.", j.Spec.Node, action, j.Id), nil
	}
}

// hardwareText is a node's hardware for a prompt: "gpu (RTX 4090, 24 GB), 64 GB RAM, 16 CPUs".
func hardwareText(n *v1.NodeStatus) string {
	var parts []string
	if len(n.Gpus) > 0 {
		var gpus []string
		for _, g := range n.Gpus {
			name := strings.TrimSpace(strings.NewReplacer("NVIDIA ", "", "GeForce ", "", "(R)", "", "(TM)", "").Replace(g.Name))
			if g.MemoryBytes > 0 {
				name += ", " + gigabytes(g.MemoryBytes)
			}
			gpus = append(gpus, name)
		}
		parts = append(parts, "gpu ("+strings.Join(gpus, "; ")+")")
	}
	if n.MemoryBytes > 0 {
		parts = append(parts, gigabytes(n.MemoryBytes)+" RAM")
	}
	if n.Cpus > 0 {
		parts = append(parts, fmt.Sprintf("%d CPUs", n.Cpus))
	}
	return strings.Join(parts, ", ")
}

func gigabytes(b int64) string {
	return fmt.Sprintf("%.0f GB", float64(b)/(1<<30))
}
