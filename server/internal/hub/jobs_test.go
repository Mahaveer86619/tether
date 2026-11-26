package hub

import (
	"context"
	"encoding/json"
	"strings"
	"sync"
	"testing"
	"time"

	"google.golang.org/protobuf/encoding/protojson"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/wire"
)

// fakeJobNode is an agent that runs pretend jobs: it answers each command
// with the state a real agent would report, and keeps what it was sent.
type fakeJobNode struct {
	conn *wire.Conn
	ctx  context.Context
	mu   sync.Mutex
	got  []*v1.AgentCommand_JobCommand
}

func newFakeJobNode(t *testing.T, h *Hub, url, name string, status *v1.NodeStatus, have ...*v1.Job) *fakeJobNode {
	t.Helper()
	ctx, cancel := context.WithCancel(context.Background())
	t.Cleanup(cancel)
	conn, err := wire.Dial(ctx, "ws"+strings.TrimPrefix(url, "http")+"/ws", "")
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { conn.Close(nil) })
	if status == nil {
		status = &v1.NodeStatus{}
	}
	status.Node = name
	_ = conn.WriteNow(ctx, &v1.Frame{Body: &v1.Frame_AgentHello{AgentHello: &v1.AgentHello{Token: "secret", Status: status}}})
	_ = conn.WriteNow(ctx, &v1.Frame{Body: &v1.Frame_JobReport{JobReport: &v1.JobReport{Jobs: have, Full: true}}})
	n := &fakeJobNode{conn: conn, ctx: ctx}
	waitUntil(t, name+" to run jobs", func() bool {
		h.mu.Lock()
		defer h.mu.Unlock()
		return h.jobNodes[name]
	})
	go func() {
		for {
			f, err := conn.Read(ctx)
			if err != nil {
				return
			}
			c := f.GetAgentCommand().GetJob()
			if c == nil {
				continue
			}
			n.mu.Lock()
			n.got = append(n.got, c)
			n.mu.Unlock()
			j := &v1.Job{Id: c.Id, Spec: c.Spec, Pid: 4242, StartedMs: time.Now().UnixMilli()}
			switch c.Action {
			case "start", "restart":
				j.State = v1.JobState_JOB_STATE_RUNNING
			case "stop":
				j.State = v1.JobState_JOB_STATE_STOPPED
			case "pause":
				j.State = v1.JobState_JOB_STATE_PAUSED
			case "resume":
				j.State = v1.JobState_JOB_STATE_RUNNING
			default:
				continue
			}
			n.report(j)
		}
	}()
	return n
}

func (n *fakeJobNode) report(jobs ...*v1.Job) {
	_ = n.conn.WriteNow(n.ctx, &v1.Frame{Body: &v1.Frame_JobReport{JobReport: &v1.JobReport{Jobs: jobs}}})
}

func (n *fakeJobNode) commands() []*v1.AgentCommand_JobCommand {
	n.mu.Lock()
	defer n.mu.Unlock()
	return append([]*v1.AgentCommand_JobCommand(nil), n.got...)
}

func getJob(t *testing.T, h *Hub, id string) *v1.Job {
	t.Helper()
	h.mu.Lock()
	defer h.mu.Unlock()
	return h.jobs[id]
}

func jobState(h *Hub, id string) v1.JobState {
	h.mu.Lock()
	defer h.mu.Unlock()
	if j := h.jobs[id]; j != nil {
		return j.State
	}
	return v1.JobState_JOB_STATE_UNSPECIFIED
}

func TestAJobIsStartedWithItsSecretsControlledAndItsLogTailed(t *testing.T) {
	h, srv := newTestHubWith(t)
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	app, err := wire.Dial(ctx, "ws"+strings.TrimPrefix(srv.URL, "http")+"/ws", "")
	if err != nil {
		t.Fatal(err)
	}
	defer app.Close(nil)
	_ = app.WriteNow(ctx, &v1.Frame{Body: &v1.Frame_ClientHello{ClientHello: &v1.ClientHello{Token: "secret", ClientName: "phone"}}})
	if _, err := app.Read(ctx); err != nil {
		t.Fatal(err)
	}

	desk := newFakeJobNode(t, h, srv.URL, "desk", nil)
	cwd := "/work/trainer"
	repo := repoName("desk", cwd)
	if code, body := call(t, srv, "PUT", "/api/v1/projects/"+repo+"/files", "secret", `{"path":".env","content":"API_KEY=\"s3cret\"\nOTHER=x\n"}`); code != 200 {
		t.Fatalf("vault put: %d %s", code, body)
	}

	code, body := call(t, srv, "POST", "/api/v1/jobs", "secret",
		`{"node":"desk","cwd":"`+cwd+`","command":"python train.py","port":8000,"restart":"on-failure","envFrom":[{"file":".env","keys":["API_KEY"]}]}`)
	if code != 200 {
		t.Fatalf("start: %d %s", code, body)
	}
	started := &v1.Job{}
	if err := protojson.Unmarshal([]byte(body), started); err != nil {
		t.Fatal(err)
	}
	waitUntil(t, "the node to run it", func() bool { return jobState(h, started.Id) == v1.JobState_JOB_STATE_RUNNING })
	cmds := desk.commands()
	if len(cmds) != 1 || cmds[0].Action != "start" || cmds[0].SecretEnv["API_KEY"] != "s3cret" || cmds[0].SecretEnv["OTHER"] != "" {
		t.Fatalf("the node should get the one key it asked for: %v", cmds)
	}
	if strings.Contains(cmds[0].Spec.Command, "s3cret") {
		t.Fatal("the secret is on the command line")
	}

	j := getJob(t, h, started.Id)
	if j.By == "" {
		t.Fatalf("who started it: %q", j.By)
	}
	if j.Spec.EnvFrom[0].Repo != repo {
		t.Fatalf("the reference should name the project: %v", j.Spec.EnvFrom)
	}
	_, list := call(t, srv, "GET", "/api/v1/jobs", "secret", "")
	if strings.Contains(list, "s3cret") || !strings.Contains(list, started.Id) {
		t.Fatalf("the list holds the job and no secret: %s", list)
	}
	h.mu.Lock()
	stored, err := h.store.Jobs()
	h.mu.Unlock()
	if err != nil || len(stored) != 1 {
		t.Fatalf("stored jobs: %v %v", stored, err)
	}
	if b, _ := protojson.Marshal(stored[0]); strings.Contains(string(b), "s3cret") {
		t.Fatal("the stored job holds the secret")
	}

	var pushed *v1.Job
	for pushed == nil || pushed.State != v1.JobState_JOB_STATE_RUNNING {
		f, err := app.Read(ctx)
		if err != nil {
			t.Fatal("the app should be told about the job: ", err)
		}
		if f.GetJob() != nil {
			pushed = f.GetJob()
		}
	}

	_ = desk.conn.WriteNow(ctx, &v1.Frame{Body: &v1.Frame_JobLog{JobLog: &v1.JobLog{Job: started.Id, Lines: []string{"epoch 1", "epoch 2", "epoch 3"}}}})
	waitUntil(t, "the log", func() bool {
		_, b := call(t, srv, "GET", "/api/v1/jobs/"+started.Id+"/logs?tail=2", "secret", "")
		tail := &v1.JobLogTail{}
		return protojson.Unmarshal([]byte(b), tail) == nil && strings.Join(tail.Lines, "|") == "epoch 2|epoch 3"
	})

	for _, action := range []string{"pause", "resume", "stop"} {
		if code, body := call(t, srv, "POST", "/api/v1/jobs/"+started.Id+"/"+action, "secret", ""); code != 200 {
			t.Fatalf("%s: %d %s", action, code, body)
		}
		want := map[string]v1.JobState{"pause": v1.JobState_JOB_STATE_PAUSED, "resume": v1.JobState_JOB_STATE_RUNNING, "stop": v1.JobState_JOB_STATE_STOPPED}[action]
		waitUntil(t, action, func() bool { return jobState(h, started.Id) == want })
	}
	if code, _ := call(t, srv, "POST", "/api/v1/jobs/"+started.Id+"/pause", "secret", ""); code != 409 {
		t.Fatalf("pausing a stopped job: %d", code)
	}
	if code, _ := call(t, srv, "DELETE", "/api/v1/jobs/"+started.Id, "secret", ""); code != 200 {
		t.Fatalf("forget: %d", code)
	}
	if getJob(t, h, started.Id) != nil {
		t.Fatal("a forgotten job is still listed")
	}
}

func TestJobsAreRefusedWhatTheyMayNotHave(t *testing.T) {
	h, srv := newTestHubWith(t)
	newFakeJobNode(t, h, srv.URL, "laptop", &v1.NodeStatus{Capabilities: []string{"go"}})

	cases := []struct {
		name, body string
		status     int
	}{
		{"no command", `{"node":"laptop","cwd":"/x"}`, 400},
		{"offline node", `{"node":"elsewhere","cwd":"/x","command":"true"}`, 503},
		{"no gpu there", `{"node":"laptop","cwd":"/x","command":"true","needsGpu":true}`, 400},
		{"no gpu anywhere", `{"cwd":"/x","command":"true","needsGpu":true}`, 503},
		{"a project not allowed", `{"node":"laptop","cwd":"/x","command":"true","envFrom":[{"repo":"someone-else","file":".env"}]}`, 403},
		{"a file the project lacks", `{"node":"laptop","cwd":"/x","command":"true","envFrom":[{"file":".env"}]}`, 400},
	}
	for _, c := range cases {
		if code, body := call(t, srv, "POST", "/api/v1/jobs", "secret", c.body); code != c.status {
			t.Errorf("%s: %d %s, want %d", c.name, code, body, c.status)
		}
	}
}

func TestAGPUJobGoesToTheMachineWithOneAndTheLeadIsTold(t *testing.T) {
	h, srv := newTestHubWith(t)
	newFakeJobNode(t, h, srv.URL, "laptop", &v1.NodeStatus{Os: "windows", Capabilities: []string{"go"}})
	desk := newFakeJobNode(t, h, srv.URL, "desk", &v1.NodeStatus{Os: "linux", Capabilities: []string{"gpu", "python"},
		Gpus: []*v1.Gpu{{Name: "NVIDIA GeForce RTX 4090", MemoryBytes: 24 << 30}}, MemoryBytes: 64 << 30, Cpus: 16})

	_, m := rpc(t, srv, "secret", `{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"start_job","arguments":{"cwd":"/work","command":"python train.py","needs_gpu":true}}}`)
	if text := toolText(t, m); !strings.Contains(text, "on desk") {
		t.Fatalf("start_job: %s", text)
	}
	waitUntil(t, "the desk to get the job", func() bool { return len(desk.commands()) == 1 })

	h.mu.Lock()
	prompt := h.leadPrompt("c1", "")
	h.mu.Unlock()
	if !strings.Contains(prompt, "desk (linux) with python, gpu (RTX 4090, 24 GB), 64 GB RAM, 16 CPUs") {
		t.Fatalf("the lead's prompt should name the GPU: %s", prompt)
	}

	_, m = rpc(t, srv, "secret", `{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"job_status","arguments":{}}}`)
	var status []map[string]any
	if err := json.Unmarshal([]byte(toolText(t, m)), &status); err != nil || len(status) != 1 || status[0]["state"] != "running" {
		t.Fatalf("job_status: %v %v", status, err)
	}
	_, m = rpc(t, srv, "secret", `{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"pause_job","arguments":{"id":"`+status[0]["id"].(string)+`"}}}`)
	if text := toolText(t, m); !strings.Contains(text, "pause") {
		t.Fatalf("pause_job: %s", text)
	}
}

func TestAJobItsAgentNoLongerHasIsLost(t *testing.T) {
	h, srv := newTestHubWith(t)
	running := &v1.Job{Id: "j1", Spec: &v1.JobSpec{Node: "desk", Cwd: "/w", Command: "serve"}, State: v1.JobState_JOB_STATE_RUNNING}
	h.mu.Lock()
	h.putJob(running)
	h.mu.Unlock()
	// The agent restarts after the device did, and finds nothing.
	newFakeJobNode(t, h, srv.URL, "desk", nil)
	if st := jobState(h, "j1"); st != v1.JobState_JOB_STATE_LOST {
		t.Fatalf("got %v, want lost", st)
	}
}

func TestAServerJobLinksToItsMachineOnTheTailnet(t *testing.T) {
	h, srv := newTestHubWith(t)
	h.cfg.TailscaleStatus = func(context.Context) ([]byte, error) {
		return []byte(`{"Self":{"DNSName":"hub.example.ts.net.","TailscaleIPs":["100.64.0.1"]},"Peer":{}}`), nil
	}
	desk := newFakeJobNode(t, h, srv.URL, "desk", nil)
	h.ownDevice("")
	code, body := call(t, srv, "POST", "/api/v1/jobs", "secret", `{"node":"desk","cwd":"/w","command":"npm run dev","port":5173}`)
	if code != 200 {
		t.Fatalf("start: %d %s", code, body)
	}
	waitUntil(t, "the job to run", func() bool { return len(desk.commands()) == 1 })
	_, body = call(t, srv, "GET", "/api/v1/jobs", "secret", "")
	list := &v1.JobList{}
	if err := protojson.Unmarshal([]byte(body), list); err != nil || len(list.Jobs) != 1 {
		t.Fatalf("list: %s %v", body, err)
	}
	// The test's agent connects from this machine, so it is the hub's own.
	if a := list.Jobs[0].Address; a != "http://hub.example.ts.net:5173" {
		t.Fatalf("address: %q", a)
	}
}
