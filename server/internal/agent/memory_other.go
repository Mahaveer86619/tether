//go:build !windows

package agent

import (
	"context"
	"os"
	"runtime"
	"strconv"
	"strings"
)

func totalMemory(ctx context.Context) int64 {
	if runtime.GOOS == "darwin" {
		out, err := output(ctx, "sysctl", "-n", "hw.memsize")
		if err != nil {
			return 0
		}
		n, _ := strconv.ParseInt(strings.TrimSpace(string(out)), 10, 64)
		return n
	}
	b, err := os.ReadFile("/proc/meminfo")
	if err != nil {
		return 0
	}
	return parseMeminfo(string(b))
}
