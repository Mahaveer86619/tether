# Tether docs

| Doc | What it covers |
|---|---|
| [architecture.md](architecture.md) | Components, who connects to whom, data flow, technology choices |
| [protocol.md](protocol.md) | The wire contract between hub, agents and app: envelope, events, commands, render blocks, tool cards |
| [hosting.md](hosting.md) | How sessions run (tmux, headless, your own terminal) and how hooks track their state and approvals |
| [sessions.md](sessions.md) | How Claude Code sessions are discovered, started, mirrored, resumed and forked |
| [running.md](running.md) | Building, deploying the hub and agents, and using `tetherctl` |
| [home-server.md](home-server.md) | Mini PC sandbox and NAS setup, plus the current state of that machine |
| [security.md](security.md) | Trust boundaries, auth, sandboxing, approvals |
| [chats.md](chats.md) | Chats: the conversations behind the app's chat UI, how they map to sessions, where they run (targets), and the context store with its post-processing jobs |
| [app.md](app.md) | The Flutter app: layers, error handling, caching, background sync, views |
| [roadmap.md](roadmap.md) | Milestones and what "done" means for each |
| [plan.md](plan.md) | Next steps beyond M4: device pairing (QR, Tailscale or a public VM), fork/branch/merge, the second brain, hub sessions, usage tracking, users and roles |
