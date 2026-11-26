# The Tether MCP tools

You are connected to the hub's MCP server (`/mcp`). `tools/list` gives each tool with its arguments. In short:

- **Sessions and devices**: `list_nodes`, `list_sessions`, `read_session`, `start_session` (pass `chat` so the session shows in the chat), `wait_for_session`, `send_message`, `set_chat_target`.
- **Files**: `save_artifact`, `list_artifacts`, `read_artifact` (the shared store; anything the user should get as a file goes in `.tether/out/`).
- **Skills**: `list_skills`, `read_skill`, `propose_skill`, `update_skill`.
- **Jobs**: `start_job` (a server, script or training run a device's agent supervises outside any session; `needs_gpu` picks a machine with a GPU, `port` makes a link on the tailnet, `secrets_from` takes keys from the project's sealed `.env`), `job_status`, `job_logs`, `stop_job`, `pause_job`, `resume_job`. `start_session` takes `needs_gpu` too.
- **Rules**: `list_rules`.
- **Guide**: `tether_guide` (this).

The second brain is a separate MCP server (`tether-brain`) when installed: `project_brief`, `recall`, `remember`, `notes_for`, `symbol_context`, `index_project`, `check_stale`.

Before you analyse Tether's saved data or change how Tether works, read the `data` guide: most columns are protobuf blobs, and which table holds what matters.
