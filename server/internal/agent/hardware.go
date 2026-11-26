package agent

import (
	"context"
	"encoding/json"
	"os/exec"
	"runtime"
	"slices"
	"strconv"
	"strings"
	"time"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// hardware is what the machine has for placing work on it: the lead's
// prompt and the Devices page show it, and a job that needs a GPU goes to
// a machine that has one.
type hardware struct {
	gpus   []*v1.Gpu
	memory int64
	cpus   int32
}

const hardwareTimeout = 20 * time.Second

func (a *Agent) probeHardware() {
	ctx, cancel := context.WithTimeout(context.Background(), hardwareTimeout)
	defer cancel()
	hw := hardware{cpus: int32(runtime.NumCPU()), memory: totalMemory(ctx), gpus: findGPUs(ctx, output)}
	a.mu.Lock()
	a.hardware = hw
	if hasGPU(hw.gpus) && !slices.Contains(a.capabilities, "gpu") {
		a.capabilities = append(slices.Clone(a.capabilities), "gpu")
		slices.Sort(a.capabilities)
	}
	a.mu.Unlock()
	a.sendStatus()
}

// runner is how a probe runs a command; tests replace it.
type runner func(ctx context.Context, name string, args ...string) ([]byte, error)

func output(ctx context.Context, name string, args ...string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, name, args...)
	hideWindow(cmd)
	return cmd.Output()
}

// findGPUs asks nvidia-smi first, which knows the real memory; on Windows
// it falls back to the video controllers Windows lists.
func findGPUs(ctx context.Context, run runner) []*v1.Gpu {
	if out, err := run(ctx, "nvidia-smi", "--query-gpu=name,memory.total", "--format=csv,noheader,nounits"); err == nil {
		if gpus := parseNvidiaSmi(string(out)); len(gpus) > 0 {
			return gpus
		}
	}
	if runtime.GOOS != "windows" {
		return nil
	}
	out, err := run(ctx, "powershell", "-NoProfile", "-NonInteractive", "-Command",
		"Get-CimInstance Win32_VideoController | Select-Object Name,AdapterRAM | ConvertTo-Json -Compress")
	if err != nil {
		return nil
	}
	return parseVideoControllers(out)
}

// parseNvidiaSmi reads lines like "NVIDIA GeForce RTX 4090, 24564" (MiB).
func parseNvidiaSmi(out string) []*v1.Gpu {
	var gpus []*v1.Gpu
	for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
		name, mem, ok := strings.Cut(line, ",")
		name = strings.TrimSpace(name)
		if !ok || name == "" {
			continue
		}
		mib, _ := strconv.ParseInt(strings.TrimSpace(mem), 10, 64)
		gpus = append(gpus, &v1.Gpu{Name: name, MemoryBytes: mib << 20})
	}
	return gpus
}

// parseVideoControllers reads Get-CimInstance's JSON: one object, or a list.
// AdapterRAM is a 32-bit field, so a card over 4 GB reads as at most 4 GB;
// it is left out rather than shown wrong.
func parseVideoControllers(out []byte) []*v1.Gpu {
	type controller struct {
		Name       string
		AdapterRAM int64
	}
	var list []controller
	if err := json.Unmarshal(out, &list); err != nil {
		var one controller
		if json.Unmarshal(out, &one) != nil {
			return nil
		}
		list = []controller{one}
	}
	var gpus []*v1.Gpu
	for _, c := range list {
		name := strings.TrimSpace(c.Name)
		if name == "" || strings.Contains(strings.ToLower(name), "basic display") || strings.Contains(strings.ToLower(name), "remote display") {
			continue
		}
		g := &v1.Gpu{Name: name}
		if c.AdapterRAM > 0 && c.AdapterRAM < 4<<30-1<<20 {
			g.MemoryBytes = c.AdapterRAM
		}
		gpus = append(gpus, g)
	}
	return gpus
}

// hasGPU is whether a GPU fit for compute is there: a discrete NVIDIA, AMD
// or Intel Arc card, not the graphics built into a CPU.
func hasGPU(gpus []*v1.Gpu) bool {
	for _, g := range gpus {
		n := strings.ToLower(g.Name)
		if strings.Contains(n, "nvidia") || strings.Contains(n, "geforce") || strings.Contains(n, "quadro") ||
			strings.Contains(n, "tesla") || strings.Contains(n, "radeon rx") || strings.Contains(n, "radeon pro") ||
			strings.Contains(n, "instinct") || strings.Contains(n, "arc(tm)") || strings.Contains(n, "intel arc") {
			return true
		}
	}
	return false
}

// parseMeminfo reads MemTotal from /proc/meminfo, given in kB.
func parseMeminfo(s string) int64 {
	for _, line := range strings.Split(s, "\n") {
		if rest, ok := strings.CutPrefix(line, "MemTotal:"); ok {
			kb, _ := strconv.ParseInt(strings.TrimSuffix(strings.TrimSpace(rest), " kB"), 10, 64)
			return kb << 10
		}
	}
	return 0
}
