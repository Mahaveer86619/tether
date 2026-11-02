package skills

import (
	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// Source is where finished sessions are read from: the hub's store.
type Source interface {
	Sessions() ([]*v1.SessionInfo, error)
	ItemsAfter(session string, after uint64) ([]*v1.TimelineItem, uint64, error)
}

// Collect reads every session and returns their tasks. A session that can't be
// read is skipped; one bad timeline shouldn't hide the rest.
func Collect(src Source) (tasks []Task, sessions int, err error) {
	infos, err := src.Sessions()
	if err != nil {
		return nil, 0, err
	}
	for _, si := range infos {
		items, _, err := src.ItemsAfter(si.GetId(), 0)
		if err != nil {
			continue
		}
		sessions++
		ts := Tasks(Meta{Session: si.GetId(), Node: si.GetNode(), Cwd: si.GetCwd()}, items)
		// Items carry no time when the transcript didn't; fall back to when the session last changed.
		for i := range ts {
			if ts[i].StartMs == 0 {
				ts[i].StartMs = si.GetUpdatedMs()
			}
		}
		tasks = append(tasks, ts...)
	}
	return tasks, sessions, nil
}
