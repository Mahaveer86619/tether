//go:build !windows

package main

import (
	"errors"

	"github.com/Mahaveer86619/tether/server/internal/winupdate"
)

// The updater is for the Windows app; elsewhere it only builds.
func platformHooks() winupdate.Hooks {
	return winupdate.Hooks{
		Start: func(string, []string) (func(), error) { return nil, errors.New("tether-updater runs on Windows only") },
	}
}
