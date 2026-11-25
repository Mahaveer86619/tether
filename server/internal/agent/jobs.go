package agent

import (
	"path/filepath"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
	"github.com/Mahaveer86619/tether/server/internal/jobs"
)

// Lines of each job's log sent again on each new hub connection, so the
// hub's tail is filled after either side restarts.
const jobTailOnConnect = 200

func (a *Agent) jobsDir() string {
	return filepath.Join(filepath.Dir(a.cfg.ScratchDir), "jobs")
}

func (a *Agent) startJobs() {
	a.jobs = jobs.New(a.jobsDir(), a.log, a.reportJob, a.sendJobLines)
	a.jobs.Recover()
}

func (a *Agent) reportJob(j *v1.Job) {
	a.send(&v1.Frame{Body: &v1.Frame_JobReport{JobReport: &v1.JobReport{Jobs: []*v1.Job{j}}}})
}

func (a *Agent) sendJobLines(id string, lines []string) {
	a.send(&v1.Frame{Body: &v1.Frame_JobLog{JobLog: &v1.JobLog{Job: id, Lines: lines}}})
}

// publishJobs sends every job and the tail of its log, on connect. Sent even
// when there are none: it tells the hub this agent runs jobs.
func (a *Agent) publishJobs() {
	if a.jobs == nil {
		return
	}
	list := a.jobs.List()
	a.send(&v1.Frame{Body: &v1.Frame_JobReport{JobReport: &v1.JobReport{Jobs: list, Full: true}}})
	for _, j := range list {
		if tail := a.jobs.Tail(j.Id, jobTailOnConnect); len(tail) > 0 {
			a.send(&v1.Frame{Body: &v1.Frame_JobLog{JobLog: &v1.JobLog{Job: j.Id, Lines: tail, Replace: true}}})
		}
	}
}

// jobCommand carries out a hub's job command. Stop and restart wait out the
// grace period, so this runs on its own goroutine.
func (a *Agent) jobCommand(c *v1.AgentCommand_JobCommand) {
	if a.jobs == nil {
		return
	}
	var err error
	switch c.Action {
	case "start":
		_, err = a.jobs.Start(c.Id, c.Spec, c.SecretEnv)
	case "restart":
		_, err = a.jobs.Restart(c.Id, c.Spec, c.SecretEnv)
	case "stop":
		err = a.jobs.Stop(c.Id)
	case "pause":
		err = a.jobs.Pause(c.Id)
	case "resume":
		err = a.jobs.Resume(c.Id)
	case "forget":
		err = a.jobs.Forget(c.Id)
	default:
		return
	}
	if err == nil {
		return
	}
	a.log.Warn("job command", "job", c.Id, "action", c.Action, "err", err)
	j := a.jobs.Get(c.Id)
	if j == nil {
		j = &v1.Job{Id: c.Id, Spec: c.Spec, State: v1.JobState_JOB_STATE_FAILED}
	}
	j.Error = c.Action + ": " + err.Error()
	a.reportJob(j)
}
