//! The code graph, from `codebase-memory-mcp`. The brain does not index code
//! itself: it keeps one `codebase-memory-mcp` process warm, asks it questions
//! over MCP, and keeps its own notes about what it hears.

use std::io::{BufRead, BufReader, Write};
use std::path::PathBuf;
use std::process::{Child, ChildStdin, Command, Stdio};
use std::sync::mpsc::{self, Receiver};
use std::sync::Mutex;
use std::time::Duration;

use serde_json::{json, Value};

/// Something that answers code-graph questions: the real tool, or a fake in a test.
pub trait Graph: Send + Sync {
    /// Calls one of the graph tool's tools and returns its text.
    fn call(&self, tool: &str, args: Value) -> Result<String, String>;
}

/// A symbol as the graph knows it right now.
#[derive(Debug, Clone, PartialEq)]
pub struct Snippet {
    pub qualified_name: String,
    pub file: String,
    pub start_line: u64,
    pub end_line: u64,
    pub source: String,
}

impl Snippet {
    /// A fingerprint of the symbol's code that ignores line endings and
    /// trailing spaces, so a different checkout of the same code matches.
    pub fn hash(&self) -> String {
        let mut h = 0xcbf29ce484222325u64;
        for line in self.source.lines() {
            for b in line.trim_end().bytes() {
                h ^= b as u64;
                h = h.wrapping_mul(0x100000001b3);
            }
            h ^= b'\n' as u64;
            h = h.wrapping_mul(0x100000001b3);
        }
        format!("{h:016x}")
    }
}

pub fn snippet(g: &dyn Graph, project: &str, symbol: &str) -> Result<Option<Snippet>, String> {
    let text = match g.call("get_code_snippet", json!({ "project": project, "qualified_name": symbol })) {
        Ok(t) => t,
        // The tool answers a missing symbol with an error; that is an answer, not a failure.
        Err(e) if e.to_lowercase().contains("not found") || e.to_lowercase().contains("no symbol") => return Ok(None),
        Err(e) => return Err(e),
    };
    let Ok(v) = serde_json::from_str::<Value>(&text) else { return Ok(None) };
    let Some(source) = v.get("source").and_then(Value::as_str) else { return Ok(None) };
    Ok(Some(Snippet {
        qualified_name: v.get("qualified_name").and_then(Value::as_str).unwrap_or(symbol).to_string(),
        file: v.get("file_path").and_then(Value::as_str).unwrap_or("").to_string(),
        start_line: v.get("start_line").and_then(Value::as_u64).unwrap_or(0),
        end_line: v.get("end_line").and_then(Value::as_u64).unwrap_or(0),
        source: source.to_string(),
    }))
}

/// The graph tool's name for a project of ours: the same name, the folder it was
/// indexed from, or a path-made name that ends in it.
pub fn resolve_project(g: &dyn Graph, project: &str) -> Result<Option<String>, String> {
    let text = g.call("list_projects", json!({}))?;
    let v: Value = serde_json::from_str(&text).map_err(|e| format!("list_projects: {e}"))?;
    let wanted = project.to_lowercase();
    let mut loose = None;
    for p in v.get("projects").and_then(Value::as_array).into_iter().flatten() {
        let name = p.get("name").and_then(Value::as_str).unwrap_or("");
        let root = p.get("root_path").and_then(Value::as_str).unwrap_or("");
        let base = root.trim_end_matches(['/', '\\']).rsplit(['/', '\\']).next().unwrap_or("").to_lowercase();
        if name.to_lowercase() == wanted || base == wanted {
            return Ok(Some(name.to_string()));
        }
        if name.to_lowercase().ends_with(&format!("-{wanted}")) {
            loose = Some(name.to_string());
        }
    }
    Ok(loose)
}

// ---- the real tool, as a warm child process ----

struct Child2 {
    child: Child,
    stdin: ChildStdin,
    lines: Receiver<String>,
    next_id: i64,
}

/// `codebase-memory-mcp` run once and kept: it takes a few seconds to start and
/// then answers in milliseconds, and idle it needs about 11 MB.
pub struct Process {
    program: PathBuf,
    args: Vec<String>,
    state: Mutex<Option<Child2>>,
    timeout: Duration,
}

impl Process {
    pub fn new(program: impl Into<PathBuf>) -> Process {
        Process::with_args(program, vec![], Duration::from_secs(300))
    }

    pub fn with_args(program: impl Into<PathBuf>, args: Vec<String>, timeout: Duration) -> Process {
        Process { program: program.into(), args, state: Mutex::new(None), timeout }
    }

    fn start(&self) -> Result<Child2, String> {
        let mut child = Command::new(&self.program)
            .args(&self.args)
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::null())
            .spawn()
            .map_err(|e| format!("cannot start {}: {e}", self.program.display()))?;
        let stdin = child.stdin.take().ok_or("no stdin")?;
        let stdout = child.stdout.take().ok_or("no stdout")?;
        let (tx, rx) = mpsc::channel();
        std::thread::spawn(move || {
            for line in BufReader::new(stdout).lines().map_while(Result::ok) {
                if tx.send(line).is_err() {
                    break;
                }
            }
        });
        let mut c = Child2 { child, stdin, lines: rx, next_id: 1 };
        let init = json!({ "protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": { "name": "tether-brain", "version": env!("CARGO_PKG_VERSION") } });
        rpc(&mut c, "initialize", init, self.timeout)?;
        writeln!(c.stdin, "{}", json!({ "jsonrpc": "2.0", "method": "notifications/initialized" })).map_err(|e| e.to_string())?;
        let _ = c.stdin.flush();
        Ok(c)
    }

    fn attempt(&self, tool: &str, args: &Value) -> Result<String, String> {
        let mut guard = self.state.lock().unwrap_or_else(|e| e.into_inner());
        if guard.is_none() {
            *guard = Some(self.start()?);
        }
        let c = guard.as_mut().unwrap();
        let r = rpc(c, "tools/call", json!({ "name": tool, "arguments": args }), self.timeout);
        if r.is_err() {
            // A child that stopped answering is dropped; the next call starts a new one.
            if let Some(mut dead) = guard.take() {
                let _ = dead.child.kill();
                let _ = dead.child.wait();
            }
        }
        r
    }
}

impl Graph for Process {
    fn call(&self, tool: &str, args: Value) -> Result<String, String> {
        match self.attempt(tool, &args) {
            Err(e) if e.starts_with("connection:") => self.attempt(tool, &args),
            other => other,
        }
    }
}

impl Drop for Process {
    fn drop(&mut self) {
        if let Ok(mut g) = self.state.lock() {
            if let Some(mut c) = g.take() {
                let _ = c.child.kill();
                let _ = c.child.wait();
            }
        }
    }
}

fn rpc(c: &mut Child2, method: &str, params: Value, timeout: Duration) -> Result<String, String> {
    let id = c.next_id;
    c.next_id += 1;
    let msg = json!({ "jsonrpc": "2.0", "id": id, "method": method, "params": params });
    writeln!(c.stdin, "{msg}").map_err(|e| format!("connection: {e}"))?;
    c.stdin.flush().map_err(|e| format!("connection: {e}"))?;
    loop {
        let line = c.lines.recv_timeout(timeout).map_err(|_| "connection: no answer from the code graph tool".to_string())?;
        let Ok(v) = serde_json::from_str::<Value>(&line) else { continue };
        if v.get("id").and_then(Value::as_i64) != Some(id) {
            continue;
        }
        if let Some(e) = v.get("error") {
            return Err(e.get("message").and_then(Value::as_str).unwrap_or("error").to_string());
        }
        let result = v.get("result").cloned().unwrap_or(Value::Null);
        let text = result.get("content").and_then(Value::as_array).and_then(|a| a.first()).and_then(|c| c.get("text")).and_then(Value::as_str).unwrap_or("").to_string();
        if result.get("isError").and_then(Value::as_bool).unwrap_or(false) {
            return Err(text);
        }
        return Ok(if method == "tools/call" { text } else { result.to_string() });
    }
}

#[cfg(test)]
pub mod fake {
    use super::*;
    use std::collections::HashMap;

    /// A graph that answers from a table, for tests.
    #[derive(Default)]
    pub struct Fake {
        pub projects: Vec<(String, String)>,
        /// qualified name to source, per project
        pub symbols: Mutex<HashMap<(String, String), (String, String)>>,
        pub calls: Mutex<Vec<String>>,
    }

    impl Fake {
        pub fn symbol(&self, project: &str, qn: &str, file: &str, source: &str) {
            self.symbols.lock().unwrap().insert((project.into(), qn.into()), (file.into(), source.into()));
        }
    }

    impl Graph for Fake {
        fn call(&self, tool: &str, args: Value) -> Result<String, String> {
            self.calls.lock().unwrap().push(tool.to_string());
            match tool {
                "list_projects" => Ok(json!({ "projects": self.projects.iter().map(|(n, r)| json!({ "name": n, "root_path": r })).collect::<Vec<_>>() }).to_string()),
                "get_code_snippet" => {
                    let key = (args["project"].as_str().unwrap().to_string(), args["qualified_name"].as_str().unwrap().to_string());
                    match self.symbols.lock().unwrap().get(&key) {
                        Some((file, source)) => Ok(json!({ "name": "x", "qualified_name": key.1, "file_path": file, "start_line": 1, "end_line": 9, "source": source }).to_string()),
                        None => Err("symbol not found".into()),
                    }
                }
                "get_architecture" => Ok("project: demo\ntotal_nodes: 12\nlanguages: 1\n  Rust 3".into()),
                "trace_path" => Ok("function: f\ncallers_total: 1\ncallers: 1\n  g 1".into()),
                "index_repository" => Ok(json!({ "project": "demo", "nodes": 12, "edges": 30, "status": "indexed" }).to_string()),
                other => Err(format!("unknown tool {other}")),
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::fake::Fake;
    use super::*;

    #[test]
    fn a_projects_graph_name_is_found_by_name_folder_or_ending() {
        let g = Fake { projects: vec![("home-me-tether".into(), "/home/me/tether".into()), ("other".into(), "/srv/stuff".into())], ..Default::default() };
        assert_eq!(resolve_project(&g, "tether").unwrap().as_deref(), Some("home-me-tether"));
        assert_eq!(resolve_project(&g, "Other").unwrap().as_deref(), Some("other"));
        assert_eq!(resolve_project(&g, "stuff").unwrap().as_deref(), Some("other"), "by the folder it was indexed from");
        assert_eq!(resolve_project(&g, "missing").unwrap(), None);
    }

    #[test]
    fn a_snippet_is_read_and_a_missing_symbol_is_none() {
        let g = Fake::default();
        g.symbol("p", "p.mod.f", "src/lib.rs", "fn f() {\r\n    1\r\n}\r\n");
        let s = snippet(&g, "p", "p.mod.f").unwrap().unwrap();
        assert_eq!((s.file.as_str(), s.start_line), ("src/lib.rs", 1));
        assert!(snippet(&g, "p", "p.mod.gone").unwrap().is_none());
    }

    #[test]
    fn the_hash_ignores_line_endings_and_trailing_spaces_but_not_code() {
        let a = Snippet { qualified_name: "q".into(), file: "f".into(), start_line: 1, end_line: 2, source: "fn f() {\r\n    1   \r\n}".into() };
        let b = Snippet { source: "fn f() {\n    1\n}".into(), ..a.clone() };
        let c = Snippet { source: "fn f() {\n    2\n}".into(), ..a.clone() };
        assert_eq!(a.hash(), b.hash());
        assert_ne!(a.hash(), c.hash());
    }
}
