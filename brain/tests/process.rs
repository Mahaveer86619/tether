//! The warm-child client, against a real child: the brain's own MCP server
//! stands in for codebase-memory-mcp, since it speaks the same protocol.

use std::time::Duration;

use serde_json::json;
use tether_brain::graph::{Graph, Process};

fn child(db: &std::path::Path) -> Process {
    Process::with_args(env!("CARGO_BIN_EXE_tether-brain"), vec!["--db".into(), db.display().to_string(), "--cbm".into(), "/nonexistent".into(), "mcp".into()], Duration::from_secs(20))
}

#[test]
fn one_child_answers_many_calls_and_returns_its_text() {
    let dir = std::env::temp_dir().join(format!("tb-proc-{}", std::process::id()));
    std::fs::create_dir_all(&dir).unwrap();
    let p = child(&dir.join("b.db"));
    let a = p.call("remember", json!({ "text": "the tunnel restarts when cloudflared exits", "project": "tether" })).unwrap();
    assert!(a.starts_with("Remembered as #1"), "{a}");
    let b = p.call("recall", json!({ "query": "tunnel restarts", "project": "tether" })).unwrap();
    assert!(b.contains("cloudflared"), "{b}");
    let e = p.call("recall", json!({})).unwrap_err();
    assert!(e.contains("query is required"), "{e}");
    drop(p);
    let _ = std::fs::remove_dir_all(&dir);
}

#[test]
fn a_program_that_is_not_there_is_an_error_not_a_hang() {
    let p = Process::with_args("/definitely/not/a/program", vec![], Duration::from_secs(2));
    assert!(p.call("list_projects", json!({})).unwrap_err().contains("cannot start"));
}
