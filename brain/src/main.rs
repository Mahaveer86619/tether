use std::io::Read;
use std::path::PathBuf;
use std::process::ExitCode;
use std::time::Instant;

use clap::{Parser, Subcommand};
use tether_brain::{markdown, Brain, Context, Link, NewMemory, Query, Scope};

#[derive(Parser)]
#[command(name = "tether-brain", version, about = "Tether's second brain: memories, notes and references")]
struct Cli {
    /// The brain's database file.
    #[arg(long, global = true, env = "TETHER_BRAIN_DB")]
    db: Option<PathBuf>,
    /// Print JSON instead of text.
    #[arg(long, global = true)]
    json: bool,
    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(clap::Args, Clone, Default)]
struct Who {
    #[arg(long)]
    project: Option<String>,
    #[arg(long)]
    task: Option<String>,
    #[arg(long)]
    session: Option<String>,
}

impl Who {
    fn ctx(&self) -> Context {
        Context { project: self.project.clone(), task: self.task.clone(), session: self.session.clone() }
    }
}

#[derive(Subcommand)]
enum Cmd {
    /// Keep something. The text is the argument, or standard input with `-`.
    Remember {
        text: String,
        /// global, project, task or session.
        #[arg(long, default_value = "global")]
        scope: String,
        /// The project, task or session it belongs to.
        #[arg(long, default_value = "")]
        key: String,
        /// note, fact, decision or reference.
        #[arg(long, default_value = "note")]
        kind: String,
        #[arg(long, default_value = "")]
        title: String,
        #[arg(long, default_value = "you")]
        source: String,
        #[arg(long, default_value = "")]
        source_ref: String,
        #[arg(long = "tag")]
        tags: Vec<String>,
        /// What it is about: kind:project:target[:file[:commit]], e.g. symbol:tether:hub.Hub.commit:server/internal/hub/hub.go
        #[arg(long = "link")]
        links: Vec<String>,
    },
    /// Find what answers a question.
    Recall {
        query: Vec<String>,
        #[command(flatten)]
        who: Who,
        /// Look in every scope, not only the ones that apply.
        #[arg(long)]
        all: bool,
        #[arg(long, default_value_t = 8)]
        limit: usize,
        #[arg(long = "kind")]
        kinds: Vec<String>,
        /// Leave out notes whose subject has changed.
        #[arg(long)]
        no_stale: bool,
    },
    /// Delete a memory for good.
    Forget { id: i64 },
    /// Show one memory.
    Show { id: i64 },
    /// The newest memories that apply.
    List {
        #[command(flatten)]
        who: Who,
        #[arg(long)]
        all: bool,
        #[arg(long, default_value_t = 20)]
        limit: usize,
    },
    /// The markdown a session reads first.
    Brief {
        #[command(flatten)]
        who: Who,
        #[arg(long, default_value_t = 8)]
        per_section: usize,
    },
    /// The memories about a symbol or file.
    NotesFor { project: String, target: String },
    /// Mark the memories about a symbol or file as stale, or current again.
    Stale {
        project: String,
        target: String,
        #[arg(long)]
        clear: bool,
    },
    /// Measure: fill a scratch database with memories and time recall.
    Bench {
        #[arg(default_value_t = 20000)]
        count: usize,
    },
}

fn main() -> ExitCode {
    match run(Cli::parse()) {
        Ok(()) => ExitCode::SUCCESS,
        Err(e) => {
            eprintln!("tether-brain: {e}");
            ExitCode::FAILURE
        }
    }
}

fn default_db() -> PathBuf {
    if let Some(x) = std::env::var_os("XDG_DATA_HOME") {
        return PathBuf::from(x).join("tether-brain").join("brain.db");
    }
    let home = std::env::var_os("HOME").or_else(|| std::env::var_os("USERPROFILE")).map(PathBuf::from).unwrap_or_else(|| PathBuf::from("."));
    home.join(".local").join("share").join("tether-brain").join("brain.db")
}

fn open(cli: &Cli) -> Result<Brain, Box<dyn std::error::Error>> {
    let path = cli.db.clone().unwrap_or_else(default_db);
    if let Some(dir) = path.parent() {
        std::fs::create_dir_all(dir)?;
    }
    Ok(Brain::open(path)?)
}

fn parse_link(s: &str) -> Result<Link, String> {
    let p: Vec<&str> = s.splitn(5, ':').collect();
    if p.len() < 3 {
        return Err(format!("a link is kind:project:target[:file[:commit]], not {s:?}"));
    }
    Ok(Link {
        kind: p[0].into(),
        project: p[1].into(),
        target: p[2].into(),
        file: p.get(3).copied().unwrap_or("").into(),
        commit: p.get(4).copied().unwrap_or("").into(),
    })
}

fn run(cli: Cli) -> Result<(), Box<dyn std::error::Error>> {
    if let Cmd::Bench { count } = cli.cmd {
        return bench(count);
    }
    let mut brain = open(&cli)?;
    match &cli.cmd {
        Cmd::Remember { text, scope, key, kind, title, source, source_ref, tags, links } => {
            let body = if text == "-" {
                let mut s = String::new();
                std::io::stdin().read_to_string(&mut s)?;
                s
            } else {
                text.clone()
            };
            let links = links.iter().map(|l| parse_link(l)).collect::<Result<Vec<_>, _>>()?;
            let id = brain.remember(NewMemory {
                scope: Some(Scope::parse(scope)?),
                scope_key: key.clone(),
                kind: kind.clone(),
                title: title.clone(),
                body,
                source: source.clone(),
                source_ref: source_ref.clone(),
                tags: tags.clone(),
                links,
            })?;
            if cli.json {
                println!("{}", serde_json::json!({ "id": id }));
            } else {
                println!("remembered #{id}");
            }
        }
        Cmd::Recall { query, who, all, limit, kinds, no_stale } => {
            let mut q = Query::new(query.join(" "));
            q.ctx = who.ctx();
            q.all_scopes = *all;
            q.limit = *limit;
            q.kinds = kinds.clone();
            q.include_stale = !no_stale;
            let hits = brain.recall(&q)?;
            if cli.json {
                println!("{}", serde_json::to_string_pretty(&hits)?);
            } else if hits.is_empty() {
                println!("nothing found");
            } else {
                for h in hits {
                    let m = &h.memory;
                    let title = if m.title.is_empty() { m.body.lines().next().unwrap_or("").to_string() } else { m.title.clone() };
                    println!("#{} [{}{}] {}{}", m.id, m.scope.as_str(), if m.scope_key.is_empty() { String::new() } else { format!(":{}", m.scope_key) }, title, if m.stale { "  (stale)" } else { "" });
                    for line in m.body.lines().take(4) {
                        println!("    {line}");
                    }
                }
            }
        }
        Cmd::Forget { id } => {
            let gone = brain.forget(*id)?;
            println!("{}", if gone { format!("forgot #{id}") } else { format!("no memory #{id}") });
            if !gone {
                return Err("nothing to forget".into());
            }
        }
        Cmd::Show { id } => match brain.get(*id)? {
            Some(m) => println!("{}", serde_json::to_string_pretty(&m)?),
            None => return Err(format!("no memory #{id}").into()),
        },
        Cmd::List { who, all, limit } => {
            let items = brain.list(&who.ctx(), *all, *limit)?;
            if cli.json {
                println!("{}", serde_json::to_string_pretty(&items)?);
            } else {
                for m in items {
                    println!("#{} [{}] {}", m.id, m.scope.as_str(), if m.title.is_empty() { m.body.lines().next().unwrap_or("") } else { &m.title });
                }
            }
        }
        Cmd::Brief { who, per_section } => print!("{}", markdown::brief(&brain, &who.ctx(), *per_section)?),
        Cmd::NotesFor { project, target } => {
            let items = brain.notes_for(project, target)?;
            println!("{}", serde_json::to_string_pretty(&items)?);
        }
        Cmd::Stale { project, target, clear } => {
            let n = brain.mark_stale(project, target, !clear)?;
            println!("{n} memories {}", if *clear { "marked current" } else { "marked stale" });
        }
        Cmd::Bench { .. } => unreachable!(),
    }
    Ok(())
}

const WORDS: &[&str] = &[
    "hub", "agent", "session", "tunnel", "token", "deploy", "release", "sqlite", "index", "graph", "symbol", "function", "route", "config", "backup", "history",
    "notification", "android", "windows", "flutter", "rust", "golang", "docker", "tailscale", "cloudflare", "vault", "secret", "branch", "commit", "merge", "chat",
    "memory", "recall", "schema", "migration", "latency", "timeout", "retry", "socket", "stream", "parser", "grammar", "resolver", "call", "import", "module",
    "package", "cache", "queue", "worker", "scheduler", "runner", "build", "test", "lint", "format", "review", "decision", "note", "reference", "project", "task",
];

fn bench(count: usize) -> Result<(), Box<dyn std::error::Error>> {
    let path = std::env::temp_dir().join(format!("tether-brain-bench-{}.db", std::process::id()));
    let _ = std::fs::remove_file(&path);
    let mut brain = Brain::open(&path)?;
    let mut seed = 0x9e3779b97f4a7c15u64;
    let mut next = move || {
        seed ^= seed << 13;
        seed ^= seed >> 7;
        seed ^= seed << 17;
        seed
    };
    // Real text has a long tail of rare words, which is what keeps keyword matching selective:
    // half the words come from a small common list, half from a large made-up vocabulary.
    let text = |n: usize, next: &mut dyn FnMut() -> u64| {
        (0..n)
            .map(|_| {
                let r = next();
                if r % 2 == 0 {
                    WORDS[((r >> 8) % WORDS.len() as u64) as usize].to_string()
                } else {
                    format!("w{}", (r >> 8) % 6000)
                }
            })
            .collect::<Vec<_>>()
            .join(" ")
    };

    let t = Instant::now();
    for i in 0..count {
        let body = text(40, &mut next);
        let title = text(4, &mut next);
        let (scope, key) = match i % 5 {
            0 => (Scope::Global, String::new()),
            1 | 2 => (Scope::Project, format!("p{}", i % 7)),
            _ => (Scope::Task, format!("t{}", i % 31)),
        };
        brain.remember(NewMemory { scope: Some(scope), scope_key: key, title, body, source: "bench".into(), ..Default::default() })?;
    }
    let insert = t.elapsed();

    let queries = 300;
    let t = Instant::now();
    let mut found = 0;
    for _ in 0..queries {
        let mut q = Query::new(text(5, &mut next));
        q.ctx.project = Some("p3".into());
        q.ctx.task = Some("t5".into());
        found += brain.recall(&q)?.len();
    }
    let recall = t.elapsed();

    let size = std::fs::metadata(&path).map(|m| m.len()).unwrap_or(0);
    println!("memories:        {count}");
    println!("insert:          {:.2?} total, {:.1} per second", insert, count as f64 / insert.as_secs_f64());
    println!("recall:          {:.2?} for {queries} queries, {:.2} ms each, {:.1} hits on average", recall, recall.as_secs_f64() * 1000.0 / queries as f64, found as f64 / queries as f64);
    println!("database file:   {:.1} MB", size as f64 / 1_048_576.0);
    if let Ok(s) = std::fs::read_to_string("/proc/self/status") {
        if let Some(l) = s.lines().find(|l| l.starts_with("VmHWM")) {
            println!("peak memory:     {}", l.trim_start_matches("VmHWM:").trim());
        }
    }
    drop(brain);
    for ext in ["", "-wal", "-shm"] {
        let _ = std::fs::remove_file(format!("{}{ext}", path.display()));
    }
    Ok(())
}
