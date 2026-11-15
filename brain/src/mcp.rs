//! The brain as an MCP server: the tools a Claude Code session uses to keep and
//! find memories. It speaks JSON-RPC, over standard input and output or over
//! HTTP, and the same handler answers both.

use std::sync::Mutex;

use serde_json::{json, Value};

use crate::markdown;
use crate::store::{Brain, Context, Link, Memory, NewMemory, Query, Scope};

const PROTOCOL: &str = "2025-03-26";

pub struct Server {
    brain: Mutex<Brain>,
}

impl Server {
    pub fn new(brain: Brain) -> Server {
        Server { brain: Mutex::new(brain) }
    }

    /// Answers one JSON-RPC message; notifications get no answer.
    pub fn handle(&self, msg: &Value) -> Option<Value> {
        let id = msg.get("id").cloned();
        let method = msg.get("method").and_then(Value::as_str).unwrap_or("");
        if id.is_none() {
            return None;
        }
        let id = id.unwrap();
        let result = match method {
            "initialize" => Ok(json!({
                "protocolVersion": PROTOCOL,
                "capabilities": { "tools": {} },
                "serverInfo": { "name": "tether-brain", "version": env!("CARGO_PKG_VERSION") },
                "instructions": "The owner's second brain. Use `project_brief` at the start of work in a project, `recall` before answering from memory, and `remember` for decisions, facts and references worth keeping. Keep memories short and specific; link them to the code symbol or file they are about."
            })),
            "ping" => Ok(json!({})),
            "tools/list" => Ok(json!({ "tools": tools() })),
            "tools/call" => Ok(self.call(msg.get("params").unwrap_or(&Value::Null))),
            other => Err((-32601, format!("method not found: {other}"))),
        };
        Some(match result {
            Ok(r) => json!({ "jsonrpc": "2.0", "id": id, "result": r }),
            Err((code, message)) => json!({ "jsonrpc": "2.0", "id": id, "error": { "code": code, "message": message } }),
        })
    }

    fn call(&self, params: &Value) -> Value {
        let name = params.get("name").and_then(Value::as_str).unwrap_or("");
        let args = params.get("arguments").cloned().unwrap_or_else(|| json!({}));
        let mut brain = self.brain.lock().unwrap_or_else(|e| e.into_inner());
        match run_tool(&mut brain, name, &args) {
            Ok(text) => json!({ "content": [{ "type": "text", "text": text }] }),
            Err(e) => json!({ "isError": true, "content": [{ "type": "text", "text": e }] }),
        }
    }
}

fn s<'a>(args: &'a Value, key: &str) -> Option<&'a str> {
    args.get(key).and_then(Value::as_str).map(str::trim).filter(|v| !v.is_empty())
}

fn strings(args: &Value, key: &str) -> Vec<String> {
    args.get(key).and_then(Value::as_array).map(|a| a.iter().filter_map(|v| v.as_str().map(str::to_string)).collect()).unwrap_or_default()
}

fn context(args: &Value) -> Context {
    Context { project: s(args, "project").map(str::to_string), task: s(args, "task").map(str::to_string), session: s(args, "session").map(str::to_string) }
}

fn run_tool(brain: &mut Brain, name: &str, args: &Value) -> Result<String, String> {
    let err = |e: crate::store::Error| e.to_string();
    match name {
        "remember" => {
            let text = s(args, "text").ok_or("text is required")?;
            let ctx = context(args);
            // The narrowest scope the caller named, unless they said which.
            let (scope, key) = match s(args, "scope") {
                Some(sc) => {
                    let scope = Scope::parse(sc).map_err(err)?;
                    let key = match scope {
                        Scope::Global => String::new(),
                        Scope::Project => ctx.project.clone().unwrap_or_default(),
                        Scope::Task => ctx.task.clone().unwrap_or_default(),
                        Scope::Session => ctx.session.clone().unwrap_or_default(),
                    };
                    (scope, key)
                }
                None => match (&ctx.task, &ctx.project) {
                    (Some(t), _) => (Scope::Task, t.clone()),
                    (None, Some(p)) => (Scope::Project, p.clone()),
                    _ => (Scope::Global, String::new()),
                },
            };
            let links = args
                .get("links")
                .and_then(Value::as_array)
                .map(|a| {
                    a.iter()
                        .map(|l| Link {
                            kind: l.get("kind").and_then(Value::as_str).unwrap_or("symbol").into(),
                            project: l.get("project").and_then(Value::as_str).or(ctx.project.as_deref()).unwrap_or("").into(),
                            target: l.get("target").and_then(Value::as_str).unwrap_or("").into(),
                            file: l.get("file").and_then(Value::as_str).unwrap_or("").into(),
                            commit: l.get("commit").and_then(Value::as_str).unwrap_or("").into(),
                        })
                        .filter(|l| !l.target.is_empty())
                        .collect()
                })
                .unwrap_or_default();
            let id = brain
                .remember(NewMemory {
                    scope: Some(scope),
                    scope_key: key.clone(),
                    kind: s(args, "kind").unwrap_or("note").into(),
                    title: s(args, "title").unwrap_or("").into(),
                    body: text.into(),
                    source: s(args, "source").unwrap_or("claude").into(),
                    source_ref: s(args, "source_ref").unwrap_or("").into(),
                    tags: strings(args, "tags"),
                    links,
                })
                .map_err(err)?;
            Ok(format!("Remembered as #{id} ({}{}).", scope.as_str(), if key.is_empty() { String::new() } else { format!(": {key}") }))
        }
        "recall" => {
            let query = s(args, "query").ok_or("query is required")?;
            let mut q = Query::new(query);
            q.ctx = context(args);
            q.all_scopes = args.get("all_scopes").and_then(Value::as_bool).unwrap_or(false);
            q.include_stale = args.get("include_stale").and_then(Value::as_bool).unwrap_or(true);
            q.kinds = strings(args, "kinds");
            q.limit = args.get("limit").and_then(Value::as_u64).unwrap_or(6) as usize;
            let hits = brain.recall(&q).map_err(err)?;
            if hits.is_empty() {
                return Ok("Nothing remembered that matches.".into());
            }
            Ok(hits.iter().map(|h| show(&h.memory)).collect::<Vec<_>>().join("\n\n"))
        }
        "forget" => {
            let id = args.get("id").and_then(Value::as_i64).ok_or("id is required")?;
            if brain.forget(id).map_err(err)? {
                Ok(format!("Forgot #{id}."))
            } else {
                Err(format!("There is no memory #{id}."))
            }
        }
        "project_brief" => markdown::brief(brain, &context(args), args.get("per_section").and_then(Value::as_u64).unwrap_or(8) as usize).map_err(err),
        "notes_for" => {
            let project = s(args, "project").ok_or("project is required")?;
            let target = s(args, "target").ok_or("target is required")?;
            let notes = brain.notes_for(project, target).map_err(err)?;
            if notes.is_empty() {
                return Ok(format!("No notes about {target}."));
            }
            Ok(notes.iter().map(show).collect::<Vec<_>>().join("\n\n"))
        }
        "mark_stale" => {
            let project = s(args, "project").ok_or("project is required")?;
            let target = s(args, "target").ok_or("target is required")?;
            let stale = args.get("stale").and_then(Value::as_bool).unwrap_or(true);
            let n = brain.mark_stale(project, target, stale).map_err(err)?;
            Ok(format!("{n} memories marked {}.", if stale { "stale" } else { "current" }))
        }
        other => Err(format!("unknown tool {other}")),
    }
}

fn show(m: &Memory) -> String {
    let title = if m.title.is_empty() { m.body.lines().next().unwrap_or("").chars().take(70).collect() } else { m.title.clone() };
    let scope = if m.scope_key.is_empty() { m.scope.as_str().to_string() } else { format!("{}: {}", m.scope.as_str(), m.scope_key) };
    let mut out = format!("#{} {} [{}, {}{}]\n{}", m.id, title, scope, m.kind, if m.stale { ", STALE" } else { "" }, m.body);
    for l in &m.links {
        out.push_str(&format!("\n  about {} {}{}", l.kind, l.target, if l.file.is_empty() { String::new() } else { format!(" ({})", l.file) }));
    }
    out
}

fn tools() -> Value {
    let proj = json!({ "type": "string", "description": "The project's name, e.g. the repository folder." });
    json!([
        {
            "name": "remember",
            "description": "Keep a decision, fact, reference or note. Short and specific. Link it to the symbol or file it is about.",
            "inputSchema": { "type": "object", "required": ["text"], "properties": {
                "text": { "type": "string" },
                "title": { "type": "string" },
                "kind": { "type": "string", "enum": ["note", "fact", "decision", "reference"] },
                "scope": { "type": "string", "enum": ["global", "project", "task", "session"], "description": "Default: the narrowest of task or project given, else global." },
                "project": proj,
                "task": { "type": "string" },
                "session": { "type": "string" },
                "tags": { "type": "array", "items": { "type": "string" } },
                "links": { "type": "array", "items": { "type": "object", "required": ["target"], "properties": {
                    "kind": { "type": "string", "enum": ["symbol", "file", "session", "url"] },
                    "project": { "type": "string" }, "target": { "type": "string" }, "file": { "type": "string" }, "commit": { "type": "string" } } } }
            } }
        },
        {
            "name": "recall",
            "description": "Find what was remembered about something. Pass the project (and task) so what applies to this work comes first.",
            "inputSchema": { "type": "object", "required": ["query"], "properties": {
                "query": { "type": "string" }, "project": proj, "task": { "type": "string" }, "session": { "type": "string" },
                "limit": { "type": "integer" }, "kinds": { "type": "array", "items": { "type": "string" } },
                "all_scopes": { "type": "boolean", "description": "Look at every project's memories, not only this one's." },
                "include_stale": { "type": "boolean" }
            } }
        },
        {
            "name": "project_brief",
            "description": "What is already known for this work: global, project and task memories, newest first. Read it at the start of a session.",
            "inputSchema": { "type": "object", "properties": { "project": proj, "task": { "type": "string" }, "session": { "type": "string" }, "per_section": { "type": "integer" } } }
        },
        {
            "name": "notes_for",
            "description": "The memories linked to a code symbol or file.",
            "inputSchema": { "type": "object", "required": ["project", "target"], "properties": { "project": proj, "target": { "type": "string", "description": "A qualified symbol name or a file path." } } }
        },
        {
            "name": "mark_stale",
            "description": "Mark the memories about a symbol or file as out of date because it changed, or as current again.",
            "inputSchema": { "type": "object", "required": ["project", "target"], "properties": { "project": proj, "target": { "type": "string" }, "stale": { "type": "boolean" } } }
        },
        {
            "name": "forget",
            "description": "Delete a memory for good.",
            "inputSchema": { "type": "object", "required": ["id"], "properties": { "id": { "type": "integer" } } }
        }
    ])
}

#[cfg(test)]
mod tests {
    use super::*;

    fn server() -> Server {
        Server::new(Brain::open_in_memory().unwrap())
    }

    fn call(sv: &Server, name: &str, args: Value) -> (bool, String) {
        let r = sv.handle(&json!({ "jsonrpc": "2.0", "id": 7, "method": "tools/call", "params": { "name": name, "arguments": args } })).unwrap();
        let res = &r["result"];
        (res["isError"].as_bool().unwrap_or(false), res["content"][0]["text"].as_str().unwrap().to_string())
    }

    #[test]
    fn it_introduces_itself_and_lists_its_tools() {
        let sv = server();
        let init = sv.handle(&json!({ "jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {} })).unwrap();
        assert_eq!(init["result"]["serverInfo"]["name"], "tether-brain");
        assert_eq!(init["id"], 1);
        let list = sv.handle(&json!({ "jsonrpc": "2.0", "id": 2, "method": "tools/list" })).unwrap();
        let names: Vec<&str> = list["result"]["tools"].as_array().unwrap().iter().map(|t| t["name"].as_str().unwrap()).collect();
        assert_eq!(names, ["remember", "recall", "project_brief", "notes_for", "mark_stale", "forget"]);
    }

    #[test]
    fn notifications_get_no_answer_and_unknown_methods_an_error() {
        let sv = server();
        assert!(sv.handle(&json!({ "jsonrpc": "2.0", "method": "notifications/initialized" })).is_none());
        let r = sv.handle(&json!({ "jsonrpc": "2.0", "id": 3, "method": "nope" })).unwrap();
        assert_eq!(r["error"]["code"], -32601);
    }

    #[test]
    fn what_is_remembered_is_recalled_in_its_scope() {
        let sv = server();
        let (err, text) = call(&sv, "remember", json!({ "text": "Releases go through the tag workflow", "project": "tether", "kind": "decision", "tags": ["release"] }));
        assert!(!err, "{text}");
        assert!(text.contains("(project: tether)"));
        call(&sv, "remember", json!({ "text": "Another project releases with make", "project": "other" }));

        let (_, found) = call(&sv, "recall", json!({ "query": "how do releases go out", "project": "tether" }));
        assert!(found.contains("tag workflow"));
        assert!(!found.contains("with make"), "another project's memory stays out");
        let (_, all) = call(&sv, "recall", json!({ "query": "releases", "all_scopes": true }));
        assert!(all.contains("tag workflow") && all.contains("with make"));
        let (_, none) = call(&sv, "recall", json!({ "query": "quantum chromodynamics", "project": "tether" }));
        assert_eq!(none, "Nothing remembered that matches.");
    }

    #[test]
    fn the_default_scope_is_the_narrowest_named() {
        let sv = server();
        assert!(call(&sv, "remember", json!({ "text": "a", "project": "p", "task": "t" })).1.contains("(task: t)"));
        assert!(call(&sv, "remember", json!({ "text": "b", "project": "p" })).1.contains("(project: p)"));
        assert!(call(&sv, "remember", json!({ "text": "c" })).1.contains("(global)"));
        assert!(call(&sv, "remember", json!({ "text": "d", "scope": "project" })).0, "a project memory needs a project");
    }

    #[test]
    fn links_staleness_and_forgetting_work_through_the_tools() {
        let sv = server();
        call(&sv, "remember", json!({ "text": "commit stores items in batches", "project": "tether", "links": [{ "target": "hub.commit", "file": "hub.go" }] }));
        let (_, notes) = call(&sv, "notes_for", json!({ "project": "tether", "target": "hub.commit" }));
        assert!(notes.contains("commit stores items") && notes.contains("about symbol hub.commit (hub.go)"));
        assert!(call(&sv, "mark_stale", json!({ "project": "tether", "target": "hub.commit" })).1.starts_with("1 memories marked stale"));
        assert!(call(&sv, "recall", json!({ "query": "commit stores", "project": "tether" })).1.contains("STALE"));
        let (_, none) = call(&sv, "recall", json!({ "query": "commit stores", "project": "tether", "include_stale": false }));
        assert_eq!(none, "Nothing remembered that matches.");
        assert!(call(&sv, "forget", json!({ "id": 1 })).1.starts_with("Forgot #1"));
        assert!(call(&sv, "forget", json!({ "id": 1 })).0, "forgetting twice is an error");
    }

    #[test]
    fn the_brief_and_bad_calls() {
        let sv = server();
        assert!(call(&sv, "project_brief", json!({ "project": "tether" })).1.contains("Nothing yet."));
        call(&sv, "remember", json!({ "text": "always run the tests", "title": "habit" }));
        assert!(call(&sv, "project_brief", json!({ "project": "tether" })).1.contains("**habit**"));
        assert!(call(&sv, "recall", json!({})).0);
        assert!(call(&sv, "nonsense", json!({})).0);
    }
}
