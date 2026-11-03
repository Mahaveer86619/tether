// skillscan lists the routines that keep coming back in a hub database, as
// docs/skills.md describes. It reads only, but opening a database can run its
// migrations, so point it at a copy:
//
//	skillscan -db copy-of-hub.db [-days 30] [-runs 3]
package main

import (
	"flag"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/Mahaveer86619/tether/server/internal/skills"
	"github.com/Mahaveer86619/tether/server/internal/store"
)

func main() {
	db := flag.String("db", "", "path to a copy of hub.db")
	days := flag.Int("days", 30, "only runs from the last this many days (0 for all)")
	runs := flag.Int("runs", 3, "least runs of a routine")
	grep := flag.String("grep", "", "list the tasks whose request contains this, with their steps, and stop")
	flag.Parse()
	if *db == "" {
		flag.Usage()
		os.Exit(2)
	}
	s, err := store.Open(*db)
	if err != nil {
		fmt.Fprintln(os.Stderr, "open:", err)
		os.Exit(1)
	}
	tasks, sessions, err := skills.Collect(s)
	if err != nil {
		fmt.Fprintln(os.Stderr, "read:", err)
		os.Exit(1)
	}
	total := len(tasks)
	if *grep != "" {
		for _, t := range tasks {
			if strings.Contains(strings.ToLower(t.Request), strings.ToLower(*grep)) {
				var keys []string
				for _, st := range t.Steps {
					keys = append(keys, st.Key)
				}
				fmt.Printf("%s %s standalone=%v steps=%v\n   %q\n", t.Session[:8], day(t.StartMs), t.Standalone(), keys, trim(t.Request, 100))
			}
		}
		return
	}
	o := skills.DefaultOptions(time.Now().UnixMilli())
	o.MinRuns = *runs
	if *days == 0 {
		o.WindowMs = 0
	} else {
		o.WindowMs = int64(*days) * 24 * 3600 * 1000
	}
	routines := 0
	for _, t := range tasks {
		if t.Routine() {
			routines++
		}
	}
	cands := skills.Cluster(tasks, o)
	fmt.Printf("%d sessions, %d tasks, %d with tool calls, %d candidate routines\n\n", sessions, total, routines, len(cands))
	for i, c := range cands {
		kind := "read-only"
		if c.Mutating {
			kind = "changes things"
		}
		fmt.Printf("%d. %q\n   %d runs in %d sessions, %s, %.0f%% clean, %s to %s\n   where: %s | %s\n",
			i+1, trim(c.Example, 110), len(c.Runs), c.Sessions, kind, c.Clean*100,
			day(c.FirstMs), day(c.LastMs), strings.Join(c.Nodes, ","), strings.Join(c.Cwds, ", "))
		for _, st := range c.Steps {
			mark := " "
			if st.Mutating {
				mark = "!"
			}
			fmt.Printf("   %s %3.0f%% %s\n", mark, st.Share*100, trim(st.Detail, 120))
		}
		fmt.Println()
	}
}

func trim(s string, n int) string {
	s = strings.Join(strings.Fields(s), " ")
	if len(s) > n {
		return s[:n] + "…"
	}
	return s
}

func day(ms int64) string {
	if ms == 0 {
		return "?"
	}
	return time.UnixMilli(ms).Format("2006-01-02")
}
