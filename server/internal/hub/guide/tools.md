# The Tether MCP tools

You are connected to the hub's MCP server (`/mcp`). `tools/list` gives each tool with its arguments. In short:

- **Sessions and devices**: `list_nodes`, `list_sessions`, `read_session`, `start_session` (pass `chat` so the session shows in the chat), `wait_for_session`, `send_message`, `set_chat_target`.
- **Files**: `save_artifact`, `list_artifacts`, `read_artifact` (the shared store; anything the user should get as a file goes in `.tether/out/`).
- **Skills**: `list_skills`, `read_skill`, `propose_skill`, `update_skill`, `check_skill_scripts`. A skill may run scripts kept in the project: its front matter lists `scripts`, `needs_env` (variable names only), `effect` (read or write) and `runs_on`; `propose_skill` and `update_skill` take the scripts' contents in `scripts` so the hub keeps a sha256 of each. Before running a skill's scripts, send their hashes to `check_skill_scripts`; a changed script flags the skill for the user's review. When the user asks for a task by skill, your instructions say "Use the skill ... exactly" with its text: follow it.
- **Rules**: `list_rules`.
- **Guide**: `tether_guide` (this).

The second brain is a separate MCP server (`tether-brain`) when installed: `project_brief`, `recall`, `remember`, `notes_for`, `symbol_context`, `index_project`, `check_stale`.

Before you analyse Tether's saved data or change how Tether works, read the `data` guide: most columns are protobuf blobs, and which table holds what matters.
