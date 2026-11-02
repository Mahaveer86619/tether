package skills

import "testing"

func TestMask(t *testing.T) {
	cases := map[string]string{
		"tail -n 40 ~/logs/wvs-v2-run-20261018.log":               "tail -n 40 ~/logs/wvs-v2-run-<date>.log",
		"backup-20261025-182517.zip":                              "backup-<date>.zip",
		"session 299b4b30-1bae-4830-b266-50546648e5a1 ended":      "session <id> ended",
		"since 2026-10-18 03:00:00 and 2026-10-21T15:00:00+05:30": "since <date> and <date>",
		"ssh synlabs@100.118.241.124 -p 7420":                     "ssh synlabs@<ip> -p <n>",
		"http://127.0.0.1:8790/api/state":                         "http://<ip>/api/state",
		"checkout 87aeed6 then reset to 0b3a05f":                  "checkout <hash> then reset to <hash>",
		"1,672,819 rows":                                          "<n> rows",
		"processed=1777417 synced=1583706":                        "processed=<n> synced=<n>",
		"at 10:14 and 20:55:30":                                   "at <time> and <time>",
		"deadbeef and 1234567":                                    "deadbeef and <n>",
		"go test ./service/uploads/...":                           "go test ./service/uploads/...",
		"row 42 of 7":                                             "row 42 of 7",
	}
	for in, want := range cases {
		if got := Mask(in); got != want {
			t.Errorf("Mask(%q)\n got  %q\n want %q", in, got, want)
		}
	}
}

func TestCommandKey(t *testing.T) {
	cases := map[string]string{
		"tmux ls":                                  "tmux ls",
		"tail -n 40 /var/log/app.log":              "tail",
		"cd /srv/app && git status --short":        "git status",
		"VAR=1 go test ./...":                      "go test",
		"sudo systemctl restart nginx":             "systemctl restart",
		`C:\Windows\System32\tailscale.exe status`: "tailscale status",
		"cat a.log | grep error | wc -l":           "cat",
		"export FOO=bar":                           "",
		"/usr/bin/curl -s http://x":                "curl",
		"docker compose ps":                        "docker compose",
	}
	for in, want := range cases {
		if got := commandKey(in); got != want {
			t.Errorf("commandKey(%q) = %q, want %q", in, got, want)
		}
	}
}

func TestMutatingCommand(t *testing.T) {
	readOnly := []string{
		"tmux ls", "tail -n 40 app.log", "pgrep -af v2sync", "git status --short", "git log --oneline -8",
		"cd /srv && ls -la", "curl -s http://127.0.0.1:8790/api/state", "docker ps", "systemctl --user is-active tether-hub",
		`psql -c "select count(*) from rows"`, "cat a.log | grep error | wc -l", "journalctl --user -u tether-hub -n 20",
		"tailscale status", "go test ./...", "tail -f app.log 2>&1", "grep -rn foo . 2>/dev/null", "tmux capture-pane -p -t wvs-v2",
	}
	for _, c := range readOnly {
		if mutatingCommand(c) {
			t.Errorf("%q is read-only", c)
		}
	}
	mutating := []string{
		"rm -rf build", "git push origin main", "git commit -m x", "scp a.txt host:~/", "echo hi > out.txt", "cat a >> b",
		`psql -c "delete from rows"`, `psql -c "UPDATE rows SET x = 1"`, "curl -X POST http://x", "curl -d a=1 http://x",
		"curl -o file.zip http://x", "sed -i s/a/b/ f", "systemctl restart nginx", "docker run alpine", "make deploy",
		"ls && rm x", "find . -name x -delete", "ls | tee out.txt", "some-unknown-tool --go",
	}
	for _, c := range mutating {
		if !mutatingCommand(c) {
			t.Errorf("%q changes things", c)
		}
	}
}

func TestStepsAreMarkedByTool(t *testing.T) {
	tasks := oneOff()
	var edits, reads int
	for _, s := range tasks[0].Steps {
		if s.Tool == "Edit" {
			edits++
			if !s.Mutating || s.Key != "Edit:.tsx" {
				t.Errorf("edit step: %+v", s)
			}
		}
		if s.Tool == "Grep" {
			reads++
			if s.Mutating {
				t.Errorf("grep step: %+v", s)
			}
		}
	}
	if edits != 2 || reads != 1 {
		t.Fatalf("steps: %+v", tasks[0].Steps)
	}
}
