package agent

import (
	"context"
	"os"
	"os/exec"
	"regexp"
	"strconv"
	"strings"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// The plan's usage limits, as `claude -p /usage` prints them for this
// machine's Claude login. The command runs locally: no model call, no
// tokens. --no-session-persistence keeps it out of the session list, and
// hooks are off so it doesn't show up as a terminal session either. (--bare
// would skip hooks too, but also the subscription login /usage reports on.)

const planInterval = 5 * time.Minute

// e.g. "Current week (all models): 9% used · resets Oct 18, 7:29pm (Asia/Kolkata)"
var limitLine = regexp.MustCompile(`(?m)^\s*Current ([^:\n]+):\s*(\d+)% used(?:\s*·\s*resets\s+([^\n]+?))?\s*$`)

func parsePlan(out string) []*v1.PlanLimit {
	var limits []*v1.PlanLimit
	for _, m := range limitLine.FindAllStringSubmatch(out, -1) {
		pct, _ := strconv.Atoi(m[2])
		limits = append(limits, &v1.PlanLimit{Label: strings.TrimSpace(m[1]), Percent: int32(pct), Resets: strings.TrimSpace(m[3])})
	}
	return limits
}

func (a *Agent) planLoop(ctx context.Context) {
	t := time.NewTicker(planInterval)
	defer t.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-t.C:
			a.checkPlan(ctx)
		}
	}
}

// checkPlan runs /usage and sends what it says to the hub.
func (a *Agent) checkPlan(ctx context.Context) {
	ctx, cancel := context.WithTimeout(ctx, 90*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, a.cfg.Claude, "-p", "/usage", "--no-session-persistence", "--settings", `{"disableAllHooks":true}`)
	cmd.Dir = os.TempDir()
	hideWindow(cmd)
	out, err := cmd.Output()
	text := strings.TrimSpace(string(out))
	pu := &v1.PlanUsage{Node: a.cfg.Node, CheckedMs: time.Now().UnixMilli(), Raw: text, Limits: parsePlan(text)}
	if err != nil {
		pu.Error = err.Error()
	} else if len(pu.Limits) == 0 {
		pu.Error = "couldn't read limits from /usage"
	}
	a.send(&v1.Frame{Body: &v1.Frame_PlanUsage{PlanUsage: pu}})
}
