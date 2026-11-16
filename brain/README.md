# Tether brain

The second brain: one small Rust program that remembers decisions, facts and references, links them to code, and serves them to Claude over MCP. It sits beside [codebase-memory-mcp](https://github.com/DeusData/codebase-memory-mcp), which it uses for the code graph; if that is not installed, memories still work and code links are skipped.

- **Store:** SQLite with a light local embedding for recall; nothing is sent anywhere.
- **Notes linked to code:** a note about a symbol or file remembers a fingerprint of that code and is flagged stale when the code changes.
- **MCP:** `tether-brain mcp` over stdio, or `tether-brain serve` over HTTP. The hub forwards it at `/brain/mcp` (hub flag `-brain`) and each agent registers it with Claude.

Tools: `project_brief`, `recall`, `remember`, `forget`, `notes_for`, `symbol_context`, `index_project`, `check_stale`, `mark_stale`.

## Build and test

```sh
cargo test
cargo build --release          # tether-brain in target/release
./build.sh                     # Linux x86-64 binary via Docker, into dist/
```

## Run

```sh
tether-brain --help
tether-brain serve             # HTTP MCP; pass the address to the hub as -brain
```

Settings: `--db` or `TETHER_BRAIN_DB` for the database file, `--cbm` or `TETHER_BRAIN_CBM` for the codebase-memory-mcp program. To install it as a service on the hub's machine: `deploy/linux/enable-brain.sh`.

Design: [docs/plans/second-brain-rust.md](../docs/plans/second-brain-rust.md).
