// Command tether-updater swaps a new version of the Tether Windows app in for
// the running one. The app copies it to a temporary folder, starts it and
// exits; it waits for the app to go, unpacks the release, swaps the folders,
// starts the new app and checks it comes up, and goes back to the old one
// if it does not. It logs to the file it is given.
package main

import (
	"flag"
	"fmt"
	"os"
	"time"

	"github.com/Mahaveer86619/tether/server/internal/winupdate"
)

func main() {
	var cfg winupdate.Config
	var logPath string
	flag.StringVar(&cfg.Zip, "zip", "", "the downloaded release")
	flag.StringVar(&cfg.App, "app", "", "the app's folder")
	flag.StringVar(&cfg.Exe, "exe", "tether.exe", "the app's executable")
	flag.StringVar(&cfg.OKFile, "ok", "", "a file the new app writes when it is up")
	flag.IntVar(&cfg.Pid, "pid", 0, "the running app's process id")
	flag.StringVar(&logPath, "log", "", "where to log")
	flag.DurationVar(&cfg.Timeout, "timeout", 30*time.Second, "how long to wait for the new app")
	flag.Parse()
	if cfg.Zip == "" || cfg.App == "" {
		fmt.Fprintln(os.Stderr, "usage: tether-updater -zip release.zip -app <app folder> [-pid N] [-ok file] [-log file]")
		os.Exit(2)
	}

	var logFile *os.File
	if logPath != "" {
		logFile, _ = os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o644)
	}
	hooks := platformHooks()
	hooks.Log = func(format string, args ...any) {
		if logFile != nil {
			fmt.Fprintf(logFile, "%s %s\n", time.Now().Format(time.RFC3339), fmt.Sprintf(format, args...))
		}
	}
	if err := winupdate.Apply(cfg, hooks); err != nil {
		hooks.Log("update failed: %v", err)
		// The app that was running is gone; bring it back whatever happened.
		if _, serr := os.Stat(cfg.App); serr == nil {
			if _, startErr := hooks.Start(cfg.App+string(os.PathSeparator)+cfg.Exe, nil); startErr != nil {
				hooks.Log("could not start the app: %v", startErr)
			}
		}
		os.Exit(1)
	}
}
