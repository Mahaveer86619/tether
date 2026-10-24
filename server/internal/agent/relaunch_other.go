//go:build !windows

package agent

import "log/slog"

// Relaunch does nothing here: systemd (Restart=always) starts the agent
// again once it exits.
func Relaunch(*slog.Logger) {}
