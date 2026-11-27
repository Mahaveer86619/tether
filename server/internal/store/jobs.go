package store

import (
	"google.golang.org/protobuf/proto"

	v1 "github.com/Mahaveer86619/tether/server/gen/tether/v1"
)

// The jobs agents run for the hub. The columns are there to be read with
// SQL; info is the whole Job. See docs/architecture/jobs.md.
const jobsSchema = `
CREATE TABLE IF NOT EXISTS jobs (
	id         TEXT PRIMARY KEY,
	node       TEXT NOT NULL,
	name       TEXT NOT NULL,
	cwd        TEXT NOT NULL,
	command    TEXT NOT NULL,
	state      TEXT NOT NULL,
	started_ms INTEGER NOT NULL,
	ended_ms   INTEGER NOT NULL,
	exit_code  INTEGER NOT NULL,
	port       INTEGER NOT NULL,
	updated_ms INTEGER NOT NULL,
	info       BLOB NOT NULL
);
`

func (s *Store) PutJob(j *v1.Job) error {
	b, err := proto.Marshal(j)
	if err != nil {
		return err
	}
	spec := j.GetSpec()
	_, err = s.db.Exec(`INSERT INTO jobs (id, node, name, cwd, command, state, started_ms, ended_ms, exit_code, port, updated_ms, info)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		ON CONFLICT(id) DO UPDATE SET node=excluded.node, name=excluded.name, cwd=excluded.cwd, command=excluded.command, state=excluded.state,
			started_ms=excluded.started_ms, ended_ms=excluded.ended_ms, exit_code=excluded.exit_code, port=excluded.port, updated_ms=excluded.updated_ms, info=excluded.info`,
		j.Id, spec.GetNode(), spec.GetName(), spec.GetCwd(), spec.GetCommand(), JobStateName(j.State),
		j.StartedMs, j.EndedMs, j.ExitCode, spec.GetPort(), j.UpdatedMs, b)
	return err
}

func (s *Store) Jobs() ([]*v1.Job, error) {
	rows, err := s.db.Query(`SELECT info FROM jobs ORDER BY updated_ms DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*v1.Job
	for rows.Next() {
		var b []byte
		if err := rows.Scan(&b); err != nil {
			return nil, err
		}
		j := &v1.Job{}
		if err := proto.Unmarshal(b, j); err != nil {
			return nil, err
		}
		out = append(out, j)
	}
	return out, rows.Err()
}

func (s *Store) DeleteJob(id string) error {
	_, err := s.db.Exec(`DELETE FROM jobs WHERE id = ?`, id)
	return err
}

// JobStateName is a state as the table and the APIs spell it: running, lost...
func JobStateName(st v1.JobState) string {
	switch st {
	case v1.JobState_JOB_STATE_STARTING:
		return "starting"
	case v1.JobState_JOB_STATE_RUNNING:
		return "running"
	case v1.JobState_JOB_STATE_PAUSED:
		return "paused"
	case v1.JobState_JOB_STATE_EXITED:
		return "exited"
	case v1.JobState_JOB_STATE_FAILED:
		return "failed"
	case v1.JobState_JOB_STATE_STOPPED:
		return "stopped"
	case v1.JobState_JOB_STATE_LOST:
		return "lost"
	case v1.JobState_JOB_STATE_QUEUED:
		return "queued"
	}
	return "unknown"
}
