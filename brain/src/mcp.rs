//! The brain as an MCP server: the tools a Claude Code session uses to keep and
//! find memories. It speaks JSON-RPC, over standard input and output or over
//! HTTP, and the same handler answers both.

use std::sync::Mutex;

use serde_json::{json, Value};

use crate::graph::{self, Graph};
use crate::markdown;
use crate::store::{Brain, Context, Link, Memory, NewMemory, Query, Scope};

const PROTOCOL: &str = "2025-03-26";

pub struct Server {
    brain: Mutex<Brain>,
    graph: Option<Box<dyn Graph>>,
}

impl Server {
    pub fn new(brain: Brain) -> Server {
        Server { brain: Mutex::new(brain), graph: None }
    }

    /// A server that can also ask the code graph, for notes about code.
    pub fn with_graph(brain: Brain, graph: Box<dyn Graph>) -> Server {
        Server { brain: Mutex::new(brain), graph: Some(graph) }
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
        match run_tool(&mut brain, self.graph.as_deref(), name, &args) {
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

fn run_tool(brain: &mut Brain, graph: Option<&dyn Graph>, name: &str, args: &Value) -> Result<String, String> {
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
                            ..Default::default()
                        })
                        .filter(|l| !l.target.is_empty())
                        .collect()
                })
                .unwrap_or_default();
            let links = pin_links(graph, links);
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
        "project_brief" => {
            let ctx = context(args);
            let mut out = markdown::brief(brain, &ctx, args.get("per_section").and_then(Value::as_u64).unwrap_or(8) as usize).map_err(err)?;
            if let (Some(g), Some(project)) = (graph, ctx.project.as_deref()) {
                if let Ok(Some(gp)) = graph::resolve_project(g, project) {
                    if let Ok(arch) = g.call("get_architecture", json!({ "project": gp })) {
                        out.push_str("\n## The code\n\n");
                        out.push_str(&arch.lines().take(60).collect::<Vec<_>>().join("\n"));
                        out.push('\n');
                    }
                }
            }
            Ok(out)
        }
        "index_project" => {
            let g = graph.ok_or(NO_GRAPH)?;
            let path = s(args, "path").ok_or("path is required")?;
            let answer = g.call("index_repository", json!({ "repo_path": path }))?;
            let v: Value = serde_json::from_str(&answer).unwrap_or(Value::Null);
            Ok(match v.get("project").and_then(Value::as_str) {
                Some(p) => format!("Indexed {path} as {p}: {} nodes, {} edges.", v["nodes"], v["edges"]),
                None => answer,
            })
        }
        "symbol_context" => {
            let g = graph.ok_or(NO_GRAPH)?;
            let project = s(args, "project").ok_or("project is required")?;
            let symbol = s(args, "symbol").ok_or("symbol is required")?;
            let gp = graph::resolve_project(g, project)?.ok_or_else(|| format!("{project} is not indexed in the code graph; use index_project first."))?;
            let snip = graph::snippet(g, &gp, symbol)?;
            let mut ids = std::collections::HashSet::new();
            let mut notes = Vec::new();
            let mut targets = vec![symbol.to_string()];
            if let Some(sn) = &snip {
                targets.push(sn.qualified_name.clone());
                if !sn.file.is_empty() {
                    targets.push(sn.file.clone());
                }
            }
            for t in targets {
                for m in brain.notes_for(project, &t).map_err(err)? {
                    if ids.insert(m.id) {
                        notes.push(m);
                    }
                }
            }
            let mut out = match &snip {
                Some(sn) => format!("{} ({}:{}-{})\n", sn.qualified_name, sn.file, sn.start_line, sn.end_line),
                None => format!("{symbol}: not found in the code graph (it may have been renamed or removed).\n"),
            };
            if snip.is_some() {
                let short = symbol.rsplit('.').next().unwrap_or(symbol);
                if let Ok(t) = g.call("trace_path", json!({ "project": gp, "function_name": short, "direction": "both", "depth": 1, "limit": 25 })) {
                    out.push('\n');
                    out.push_str(&t.lines().take(40).collect::<Vec<_>>().join("\n"));
                    out.push('\n');
                }
            }
            if notes.is_empty() {
                out.push_str("\nNo notes about it yet.");
            } else {
                out.push_str("\nNotes:\n\n");
                out.push_str(&notes.iter().map(show).collect::<Vec<_>>().join("\n\n"));
            }
            Ok(out)
        }
        "check_stale" => {
            let g = graph.ok_or(NO_GRAPH)?;
            let project = s(args, "project").ok_or("project is required")?;
            let gp = graph::resolve_project(g, project)?.ok_or_else(|| format!("{project} is not indexed in the code graph; use index_project first."))?;
            check_stale(brain, g, project, &gp)
        }
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

const NO_GRAPH: &str = "The code graph is not set up on this machine (codebase-memory-mcp was not found).";

/// Stores each symbol link against the code as it is now: the qualified name,
/// the file, and a fingerprint of the source, when the graph can say.
fn pin_links(graph: Option<&dyn Graph>, links: Vec<Link>) -> Vec<Link> {
    let Some(g) = graph else { return links };
    links
        .into_iter()
        .map(|mut l| {
            if l.kind == "symbol" && !l.project.is_empty() {
                if let Ok(Some(gp)) = graph::resolve_project(g, &l.project) {
                    if let Ok(Some(sn)) = graph::snippet(g, &gp, &l.target) {
                        l.target = sn.qualified_name.clone();
                        if l.file.is_empty() {
                            l.file = sn.file.clone();
                        }
                        l.code_hash = sn.hash();
                    }
                }
            }
            l
        })
        .collect()
}

/// Compares every symbol link in a project with the code now: a symbol that has
/// gone, or whose code has changed since the note was written, makes its notes
/// stale; one that matches again makes them current.
fn check_stale(brain: &mut Brain, g: &dyn Graph, project: &str, gp: &str) -> Result<String, String> {
    let err = |e: crate::store::Error| e.to_string();
    let links = brain.symbol_links(project).map_err(err)?;
    let (mut current, mut baselined) = (0, 0);
    let mut bad: std::collections::BTreeMap<i64, Vec<String>> = std::collections::BTreeMap::new();
    let mut all: std::collections::BTreeSet<i64> = std::collections::BTreeSet::new();
    for l in &links {
        all.insert(l.memory);
        match graph::snippet(g, gp, &l.link.target)? {
            None => bad.entry(l.memory).or_default().push(format!("{} is gone", l.link.target)),
            Some(sn) if l.link.code_hash.is_empty() => {
                brain.set_link_hash(l.link_id, &sn.hash()).map_err(err)?;
                baselined += 1;
            }
            Some(sn) if sn.hash() != l.link.code_hash => bad.entry(l.memory).or_default().push(format!("{} has changed", l.link.target)),
            Some(_) => current += 1,
        }
    }
    let was: std::collections::HashMap<i64, bool> = links.iter().map(|l| (l.memory, l.stale)).collect();
    for m in &all {
        let stale = bad.contains_key(m);
        if was.get(m).copied().unwrap_or(false) != stale {
            brain.set_stale(*m, stale).map_err(err)?;
        }
    }
    let mut out = format!("Checked {} links in {project}: {current} current, {} notes out of date, {baselined} recorded for the first time.", links.len(), bad.len());
    for (m, why) in &bad {
        out.push_str(&format!("\n  #{m}: {}", why.join("; ")));
    }
    Ok(out)
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
            "name": "index_project",
            "description": "Have the code graph read a project's source folder, so notes can be tied to its code. Slow for a big project; run it once, it keeps itself current.",
            "inputSchema": { "type": "object", "required": ["path"], "properties": { "path": { "type": "string", "description": "The folder on this machine." } } }
        },
        {
            "name": "symbol_context",
            "description": "A function, method or type: where it is, what calls it and what it calls, and every note about it or its file.",
            "inputSchema": { "type": "object", "required": ["project", "symbol"], "properties": { "project": proj, "symbol": { "type": "string", "description": "A qualified name (from the code graph) or a short name." } } }
        },
        {
            "name": "check_stale",
            "description": "Compare the notes tied to code with the code now: those whose symbol changed or went away are marked stale, those that match again are made current.",
            "inputSchema": { "type": "object", "required": ["project"], "properties": { "project": proj } }
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
        assert_eq!(names, ["remember", "recall", "project_brief", "notes_for", "mark_stale", "index_project", "symbol_context", "check_stale", "forget"]);
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

    mod with_graph {
        use super::*;
        use crate::graph::fake::Fake;
        use std::sync::Arc;

        /// The fake graph is shared so a test can change the code under the notes.
        struct Shared(Arc<Fake>);
        impl Graph for Shared {
            fn call(&self, tool: &str, args: Value) -> Result<String, String> {
                self.0.call(tool, args)
            }
        }

        fn graphed() -> (Server, Arc<Fake>) {
            let fake = Arc::new(Fake { projects: vec![("home-me-tether".into(), "/home/me/tether".into())], ..Default::default() });
            fake.symbol("home-me-tether", "home-me-tether.hub.commit", "hub.go", "func commit() {
	return 1
}");
            fake.symbol("home-me-tether", "home-me-tether.hub.other", "other.go", "func other() {}");
            (Server::with_graph(Brain::open_in_memory().unwrap(), Box::new(Shared(fake.clone()))), fake)
        }

        #[test]
        fn a_symbol_link_is_pinned_to_the_code_as_it_is() {
            let (sv, _) = graphed();
            call(&sv, "remember", json!({ "text": "commit stores in batches", "project": "tether", "links": [{ "target": "commit" }, { "target": "home-me-tether.hub.commit" }] }));
            // Asking for the notes by qualified name or by file finds it: the link was completed from the graph.
            assert!(call(&sv, "notes_for", json!({ "project": "tether", "target": "home-me-tether.hub.commit" })).1.contains("commit stores in batches"));
            let (_, ctx) = call(&sv, "symbol_context", json!({ "project": "tether", "symbol": "home-me-tether.hub.commit" }));
            assert!(ctx.contains("hub.go:1-9"), "{ctx}");
            assert!(ctx.contains("commit stores in batches"), "{ctx}");
            assert!(ctx.contains("callers_total"), "{ctx}");
        }

        #[test]
        fn check_stale_marks_changed_and_missing_code_and_clears_it_again() {
            let (sv, fake) = graphed();
            call(&sv, "remember", json!({ "text": "commit stores in batches", "project": "tether", "links": [{ "target": "home-me-tether.hub.commit" }] }));
            call(&sv, "remember", json!({ "text": "other is trivial", "project": "tether", "links": [{ "target": "home-me-tether.hub.other" }] }));
            let (_, r) = call(&sv, "check_stale", json!({ "project": "tether" }));
            assert!(r.contains("2 current, 0 notes out of date"), "{r}");

            // The code under the first note changes; the second symbol goes away.
            fake.symbol("home-me-tether", "home-me-tether.hub.commit", "hub.go", "func commit() {
	return 2
}");
            fake.symbols.lock().unwrap().remove(&("home-me-tether".to_string(), "home-me-tether.hub.other".to_string()));
            let (_, r) = call(&sv, "check_stale", json!({ "project": "tether" }));
            assert!(r.contains("2 notes out of date"), "{r}");
            assert!(r.contains("hub.commit has changed") && r.contains("hub.other is gone"), "{r}");
            assert!(call(&sv, "recall", json!({ "query": "commit batches", "project": "tether" })).1.contains("STALE"));

            // Put the first back as it was: its note is current again.
            fake.symbol("home-me-tether", "home-me-tether.hub.commit", "hub.go", "func commit() {
	return 1
}");
            let (_, r) = call(&sv, "check_stale", json!({ "project": "tether" }));
            assert!(r.contains("1 current, 1 notes out of date"), "{r}");
            assert!(!call(&sv, "recall", json!({ "query": "commit batches", "project": "tether" })).1.contains("STALE"));
        }

        #[test]
        fn the_brief_gets_the_architecture_and_unindexed_projects_are_told_so() {
            let (sv, _) = graphed();
            let (_, brief) = call(&sv, "project_brief", json!({ "project": "tether" }));
            assert!(brief.contains("## The code") && brief.contains("total_nodes: 12"), "{brief}");
            let (_, plain) = call(&sv, "project_brief", json!({ "project": "elsewhere" }));
            assert!(!plain.contains("## The code"));
            let (err, why) = call(&sv, "symbol_context", json!({ "project": "elsewhere", "symbol": "x" }));
            assert!(err && why.contains("not indexed"), "{why}");
            let (ok, idx) = call(&sv, "index_project", json!({ "path": "/home/me/tether" }));
            assert!(!ok && idx.contains("12 nodes"), "{idx}");
        }

        #[test]
        fn without_a_graph_the_code_tools_say_so() {
            let sv = server();
            for tool in [("check_stale", json!({ "project": "p" })), ("symbol_context", json!({ "project": "p", "symbol": "s" })), ("index_project", json!({ "path": "/x" }))] {
                let (err, why) = call(&sv, tool.0, tool.1);
                assert!(err && why.contains("not set up"), "{}: {why}", tool.0);
            }
        }
    }
}
