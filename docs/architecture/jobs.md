# Jobs

A job is a process an agent starts and supervises for the hub: a dev server, a script, a training run. It is not a Claude Code session and uses no Claude login; it runs under the device's own user, like anything else the agent starts. The plan it comes from is [shared-workspace.md](../plans/shared-workspace.md#jobs).

```
App / lead's MCP ──POST /api/v1/jobs──► Hub ──AgentCommand.job (start, secret_env)──► Agent ──► process group / Job Object
App ◄──job frames, GET …/logs──────────  Hub ◄──JobReport, JobLog──────────────────── Agent ◄── output.log (tailed)
```

## On the agent (`server/internal/jobs`)

| Part | How |
|---|---|
| Start | The command runs in the platform's shell (`/bin/sh -c`, `cmd /d /s /c`) in the job's folder, with the agent's environment, the job's plain `env`, then the secrets the hub sent. Linux and macOS: its own process group (`Setpgid`). Windows: started suspended, put in a new Job Object, then resumed, so no child escapes. |
| Output | stdout and stderr go straight to `<agent data>/jobs/<id>/output.log` (the process holds the file, not a pipe, so it survives the agent). The agent tails the file every 500 ms and sends new lines to the hub. Above the cap (8 MB) the last half is kept in `output.log.1` and the log is emptied; the process keeps appending at the new end. Lines written between that copy and the truncation are lost. |
| Stop | The checkpoint command first, if the job has one (2 minutes at most). A paused job is resumed. Then `SIGTERM` to the group, and `SIGKILL` after the grace period (10 s). On Windows the polite step is `taskkill /T` without `/F`, which only reaches programs with a window; console programs are ended at once with `TerminateJobObject`. |
| Pause, resume | `SIGSTOP` / `SIGCONT` to the group. Windows: every thread of every process in the Job Object is suspended or resumed. Memory and a GPU's memory stay held; peers of a paused server may time out. |
| End | When the job's own process ends, whatever is left of its group is ended too. Exit 0 is `exited`; another code is `failed`; a stop is `stopped`. |
| Restart policy | `never`, `on-failure` or `always`, at most `restart_limit` times (5 by default), waiting 1 s, 2 s, 4 s and so on, up to 30 s. A manual restart resets the count. |
| Records | `<agent data>/jobs/<id>/job.json`: the job without its secrets, its pid, and the process's creation time. Records of jobs that ended more than 7 days ago are deleted at start. |
| Agent restart | Jobs are not ended when the agent stops or updates itself. At start, the agent reads its records: a process that is still there (same pid and, on Windows, the same creation time) is followed again, in a new Job Object on Windows, and its exit code is then unknown. One that is gone is `lost`: the device restarted or slept. |

States: `starting` (a server until its port takes connections on localhost), `running`, `paused`, `exited`, `failed`, `stopped`, `lost`.

## On the hub (`server/internal/hub/jobs.go`)

- The `jobs` table holds every job (plain columns plus the `Job` blob) and the hub keeps the newest 2000 lines of each job's output in memory. On each connection the agent sends all its jobs (`JobReport.full`) and the last 200 lines of each (`JobLog.replace`), so either side can restart. A live job the agent no longer has becomes `lost`.
- An agent that has sent a `JobReport` runs jobs; older agents get a clear error instead of a command they would ignore.
- **Secrets.** A job's `env_from` names keys in a project's sealed setup files ([remote-projects.md](../plans/remote-projects.md)). The hub opens them only when it sends a start, and only for a device the owner allowed for that project, or the device the project's folder is on. Values travel in `JobCommand.secret_env`, which the agent keeps in memory for restarts; neither side stores them, and they never appear on a command line. An empty `repo` means the project of the job's own folder.
- **Servers.** A job with a port gets `address`: `http://<machine>:<port>`, with the machine's MagicDNS name from the hub's `tailscale status`, or the address its agent connects from. Nothing is opened beyond the tailnet; the process itself decides which interfaces it listens on.
- **GPUs.** A job with `needs_gpu` and no node goes to an online machine with the `gpu` capability, the one running fewest jobs. `start_session` takes `needs_gpu` the same way.
- Every start and action is in the audit log.

REST, MCP tools and frames are listed in [protocol.md](protocol.md#jobs).

## Device hardware

The agent reports `gpus` (name, memory), `memory_bytes` and `cpus` in its `NodeStatus`. GPUs come from `nvidia-smi`, and on Windows from `Win32_VideoController` when there is no `nvidia-smi` (its memory field stops at 4 GB, so a card over that shows no memory). A discrete NVIDIA, AMD or Intel Arc card adds the `gpu` capability. The lead's prompt lists each machine as, for example, `desk (windows) with git, python, gpu (RTX 4090, 24 GB), 64 GB RAM, 16 CPUs`.

## Not yet

- Moving a job to another device (checkpoint, sync, start there).
- Showing a job in a chat's Tasks strip.
- Who may start jobs on whose device. Today any paired app or session can start a job on any connected agent; lending a device to other users is part of [teams.md](../plans/teams.md) (B3).
