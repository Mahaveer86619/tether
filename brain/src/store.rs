use std::collections::HashMap;
use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};

use rusqlite::{params, params_from_iter, Connection, OptionalExtension, Row};
use serde::{Deserialize, Serialize};

use crate::embed;

#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("database: {0}")]
    Db(#[from] rusqlite::Error),
    #[error("{0}")]
    Invalid(String),
}

pub type Result<T> = std::result::Result<T, Error>;

/// What a memory is about, and so who gets it: everything, one project, one
/// task, or one session.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Scope {
    Global,
    Project,
    Task,
    Session,
}

impl Scope {
    pub fn as_str(self) -> &'static str {
        match self {
            Scope::Global => "global",
            Scope::Project => "project",
            Scope::Task => "task",
            Scope::Session => "session",
        }
    }

    pub fn parse(s: &str) -> Result<Scope> {
        match s {
            "global" => Ok(Scope::Global),
            "project" => Ok(Scope::Project),
            "task" => Ok(Scope::Task),
            "session" => Ok(Scope::Session),
            other => Err(Error::Invalid(format!("unknown scope {other:?}; use global, project, task or session"))),
        }
    }
}

/// A pointer from a memory to something it is about: a code symbol, a file, a
/// session or a page. For code, `commit` says which version it was written against.
#[derive(Debug, Clone, Default, PartialEq, Serialize, Deserialize)]
pub struct Link {
    /// "symbol", "file", "session" or "url".
    pub kind: String,
    #[serde(default)]
    pub project: String,
    pub target: String,
    #[serde(default)]
    pub file: String,
    #[serde(default)]
    pub commit: String,
    /// A fingerprint of the symbol's code when the note was written, so a later
    /// check can tell the code has changed under it.
    #[serde(default)]
    pub code_hash: String,
}

/// A link and what it belongs to, for checking links against the code.
#[derive(Debug, Clone)]
pub struct LinkRef {
    pub link_id: i64,
    pub memory: i64,
    pub link: Link,
    /// Whether the memory is stale now.
    pub stale: bool,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct NewMemory {
    pub scope: Option<Scope>,
    /// The project, task or session the memory belongs to; empty for global.
    #[serde(default)]
    pub scope_key: String,
    /// "note", "fact", "decision" or "reference".
    #[serde(default)]
    pub kind: String,
    #[serde(default)]
    pub title: String,
    pub body: String,
    /// Where it came from: "you", "chat", "commit", "ingest".
    #[serde(default)]
    pub source: String,
    #[serde(default)]
    pub source_ref: String,
    #[serde(default)]
    pub tags: Vec<String>,
    #[serde(default)]
    pub links: Vec<Link>,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct Memory {
    pub id: i64,
    pub scope: Scope,
    pub scope_key: String,
    pub kind: String,
    pub title: String,
    pub body: String,
    pub source: String,
    pub source_ref: String,
    pub tags: Vec<String>,
    pub created_ms: i64,
    pub updated_ms: i64,
    /// What it is about has moved or gone since it was written.
    pub stale: bool,
    pub links: Vec<Link>,
}

/// Who is asking, which decides which memories apply.
#[derive(Debug, Clone, Default)]
pub struct Context {
    pub project: Option<String>,
    pub task: Option<String>,
    pub session: Option<String>,
}

#[derive(Debug, Clone)]
pub struct Query {
    pub text: String,
    pub ctx: Context,
    /// Look in every scope, not just the ones that apply to `ctx`.
    pub all_scopes: bool,
    pub kinds: Vec<String>,
    pub include_stale: bool,
    pub limit: usize,
}

impl Query {
    pub fn new(text: impl Into<String>) -> Query {
        Query { text: text.into(), ctx: Context::default(), all_scopes: false, kinds: vec![], include_stale: true, limit: 8 }
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct Hit {
    pub memory: Memory,
    pub score: f64,
    /// Place in the keyword ranking and in the similarity ranking, when it was in them.
    pub keyword_rank: Option<usize>,
    pub similar_rank: Option<usize>,
}

pub struct Brain {
    db: Connection,
}

pub fn now_ms() -> i64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_millis() as i64).unwrap_or(0)
}

const SCHEMA: &str = "
CREATE TABLE IF NOT EXISTS memories (
    id         INTEGER PRIMARY KEY,
    scope      TEXT NOT NULL,
    scope_key  TEXT NOT NULL DEFAULT '',
    kind       TEXT NOT NULL DEFAULT 'note',
    title      TEXT NOT NULL DEFAULT '',
    body       TEXT NOT NULL,
    source     TEXT NOT NULL DEFAULT '',
    source_ref TEXT NOT NULL DEFAULT '',
    tags       TEXT NOT NULL DEFAULT '',
    created_ms INTEGER NOT NULL,
    updated_ms INTEGER NOT NULL,
    stale      INTEGER NOT NULL DEFAULT 0,
    vec        BLOB NOT NULL
);
CREATE INDEX IF NOT EXISTS memories_by_scope ON memories (scope, scope_key);
CREATE TABLE IF NOT EXISTS links (
    id      INTEGER PRIMARY KEY,
    memory  INTEGER NOT NULL REFERENCES memories(id) ON DELETE CASCADE,
    kind    TEXT NOT NULL,
    project TEXT NOT NULL DEFAULT '',
    target  TEXT NOT NULL,
    file    TEXT NOT NULL DEFAULT '',
    commit_sha TEXT NOT NULL DEFAULT '',
    code_hash  TEXT NOT NULL DEFAULT ''
);
CREATE INDEX IF NOT EXISTS links_by_target ON links (project, target);
CREATE INDEX IF NOT EXISTS links_by_memory ON links (memory);
CREATE VIRTUAL TABLE IF NOT EXISTS memories_fts USING fts5(
    title, body, tags, content='memories', content_rowid='id', tokenize='porter unicode61'
);
CREATE TRIGGER IF NOT EXISTS memories_ai AFTER INSERT ON memories BEGIN
    INSERT INTO memories_fts(rowid, title, body, tags) VALUES (new.id, new.title, new.body, new.tags);
END;
CREATE TRIGGER IF NOT EXISTS memories_ad AFTER DELETE ON memories BEGIN
    INSERT INTO memories_fts(memories_fts, rowid, title, body, tags) VALUES ('delete', old.id, old.title, old.body, old.tags);
END;
CREATE TRIGGER IF NOT EXISTS memories_au AFTER UPDATE OF title, body, tags ON memories BEGIN
    INSERT INTO memories_fts(memories_fts, rowid, title, body, tags) VALUES ('delete', old.id, old.title, old.body, old.tags);
    INSERT INTO memories_fts(rowid, title, body, tags) VALUES (new.id, new.title, new.body, new.tags);
END;
";

const MEMORY_COLUMNS: &str = "id, scope, scope_key, kind, title, body, source, source_ref, tags, created_ms, updated_ms, stale";

/// How many candidates each ranking contributes before they are merged.
const CANDIDATES: usize = 60;
/// The constant in reciprocal rank fusion; 60 is the usual value.
const RRF_K: f64 = 60.0;

impl Brain {
    pub fn open(path: impl AsRef<Path>) -> Result<Brain> {
        let db = Connection::open(path)?;
        Brain::init(db)
    }

    pub fn open_in_memory() -> Result<Brain> {
        Brain::init(Connection::open_in_memory()?)
    }

    fn init(db: Connection) -> Result<Brain> {
        db.pragma_update(None, "journal_mode", "WAL")?;
        db.pragma_update(None, "synchronous", "NORMAL")?;
        db.pragma_update(None, "foreign_keys", "ON")?;
        db.busy_timeout(std::time::Duration::from_secs(5))?;
        db.execute_batch(SCHEMA)?;
        // Databases made before links carried a code hash get the column.
        let has_hash = db.prepare("PRAGMA table_info(links)")?.query_map([], |r| r.get::<_, String>(1))?.filter_map(|c| c.ok()).any(|c| c == "code_hash");
        if !has_hash {
            db.execute_batch("ALTER TABLE links ADD COLUMN code_hash TEXT NOT NULL DEFAULT ''")?;
        }
        Ok(Brain { db })
    }

    /// Stores a memory and returns its id.
    pub fn remember(&mut self, m: NewMemory) -> Result<i64> {
        if m.body.trim().is_empty() {
            return Err(Error::Invalid("a memory needs some text".into()));
        }
        let scope = m.scope.unwrap_or(Scope::Global);
        if scope != Scope::Global && m.scope_key.trim().is_empty() {
            return Err(Error::Invalid(format!("a {} memory needs its {} name", scope.as_str(), scope.as_str())));
        }
        let kind = if m.kind.is_empty() { "note".to_string() } else { m.kind };
        let tags = m.tags.iter().map(|t| t.trim().to_lowercase()).filter(|t| !t.is_empty()).collect::<Vec<_>>().join(" ");
        let vec = embed::quantize(&embed::embed(&format!("{} {} {} {}", m.title, m.body, tags, kind)));
        let now = now_ms();
        let tx = self.db.transaction()?;
        tx.execute(
            "INSERT INTO memories (scope, scope_key, kind, title, body, source, source_ref, tags, created_ms, updated_ms, vec)
             VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?9, ?10)",
            params![scope.as_str(), if scope == Scope::Global { "" } else { m.scope_key.trim() }, kind, m.title.trim(), m.body.trim(), m.source, m.source_ref, tags, now, vec],
        )?;
        let id = tx.last_insert_rowid();
        for l in &m.links {
            tx.execute(
                "INSERT INTO links (memory, kind, project, target, file, commit_sha, code_hash) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
                params![id, l.kind, l.project, l.target, l.file, l.commit, l.code_hash],
            )?;
        }
        tx.commit()?;
        Ok(id)
    }

    /// Replaces a memory's title, text and tags.
    pub fn update(&mut self, id: i64, title: &str, body: &str, tags: &[String]) -> Result<bool> {
        if body.trim().is_empty() {
            return Err(Error::Invalid("a memory needs some text".into()));
        }
        let tags = tags.iter().map(|t| t.trim().to_lowercase()).filter(|t| !t.is_empty()).collect::<Vec<_>>().join(" ");
        let kind: Option<String> = self.db.query_row("SELECT kind FROM memories WHERE id = ?1", [id], |r| r.get(0)).optional()?;
        let Some(kind) = kind else { return Ok(false) };
        let vec = embed::quantize(&embed::embed(&format!("{title} {body} {tags} {kind}")));
        let n = self.db.execute(
            "UPDATE memories SET title = ?2, body = ?3, tags = ?4, vec = ?5, updated_ms = ?6 WHERE id = ?1",
            params![id, title.trim(), body.trim(), tags, vec, now_ms()],
        )?;
        Ok(n > 0)
    }

    /// Deletes a memory for good, and its links.
    pub fn forget(&mut self, id: i64) -> Result<bool> {
        Ok(self.db.execute("DELETE FROM memories WHERE id = ?1", [id])? > 0)
    }

    pub fn get(&self, id: i64) -> Result<Option<Memory>> {
        let m = self
            .db
            .query_row(&format!("SELECT {MEMORY_COLUMNS} FROM memories WHERE id = ?1"), [id], read_memory)
            .optional()?;
        match m {
            Some(mut m) => {
                m.links = self.links_of(m.id)?;
                Ok(Some(m))
            }
            None => Ok(None),
        }
    }

    fn links_of(&self, id: i64) -> Result<Vec<Link>> {
        let mut st = self.db.prepare("SELECT kind, project, target, file, commit_sha, code_hash FROM links WHERE memory = ?1 ORDER BY id")?;
        let rows = st.query_map([id], |r| Ok(Link { kind: r.get(0)?, project: r.get(1)?, target: r.get(2)?, file: r.get(3)?, commit: r.get(4)?, code_hash: r.get(5)? }))?;
        Ok(rows.collect::<std::result::Result<Vec<_>, _>>()?)
    }

    /// The memories that apply to `ctx`, newest first: the ones you would want
    /// at the start of a session.
    pub fn list(&self, ctx: &Context, all_scopes: bool, limit: usize) -> Result<Vec<Memory>> {
        let (clause, args) = scope_clause(ctx, all_scopes);
        let sql = format!("SELECT {MEMORY_COLUMNS} FROM memories m WHERE {clause} ORDER BY updated_ms DESC LIMIT {}", limit.clamp(1, 1000));
        let mut st = self.db.prepare(&sql)?;
        let mut out = st.query_map(params_from_iter(args.iter()), read_memory)?.collect::<std::result::Result<Vec<_>, _>>()?;
        for m in &mut out {
            m.links = self.links_of(m.id)?;
        }
        Ok(out)
    }

    /// Finds the memories that best answer a question: keyword ranking and
    /// similarity ranking merged, restricted to what applies to the asker.
    pub fn recall(&self, q: &Query) -> Result<Vec<Hit>> {
        let limit = q.limit.clamp(1, 100);
        let (clause, scope_args) = scope_clause(&q.ctx, q.all_scopes);
        let mut filter = clause;
        if !q.include_stale {
            filter.push_str(" AND m.stale = 0");
        }
        if !q.kinds.is_empty() {
            filter.push_str(&format!(" AND m.kind IN ({})", vec!["?"; q.kinds.len()].join(",")));
        }
        let mut args: Vec<String> = scope_args;
        args.extend(q.kinds.iter().cloned());

        // Keyword ranking: every word of the question, any of them matching, best first.
        let words = embed::tokens(&q.text);
        let mut keyword: Vec<i64> = Vec::new();
        if !words.is_empty() {
            let mut seen = std::collections::HashSet::new();
            let expr = words.iter().filter(|w| seen.insert((*w).clone())).map(|w| format!("\"{}\"", w.replace('"', ""))).collect::<Vec<_>>().join(" OR ");
            let sql = format!(
                "SELECT m.id FROM memories_fts f JOIN memories m ON m.id = f.rowid WHERE memories_fts MATCH ?1 AND {} ORDER BY bm25(memories_fts, 4.0, 1.0, 2.0) LIMIT {CANDIDATES}",
                renumber(&filter, 2)
            );
            let mut all = vec![expr];
            all.extend(args.iter().cloned());
            let mut st = self.db.prepare(&sql)?;
            keyword = st.query_map(params_from_iter(all.iter()), |r| r.get::<_, i64>(0))?.collect::<std::result::Result<Vec<_>, _>>()?;
        }

        // Similarity ranking: the closest vectors among what applies.
        let qv = embed::quantize(&embed::embed(&q.text));
        let mut similar: Vec<(i64, f32)> = Vec::new();
        if qv.iter().any(|b| *b != 0) {
            let sql = format!("SELECT m.id, m.vec FROM memories m WHERE {}", renumber(&filter, 1));
            let mut st = self.db.prepare(&sql)?;
            let mut rows = st.query(params_from_iter(args.iter()))?;
            let mut top: Vec<(i64, f32)> = Vec::new();
            while let Some(r) = rows.next()? {
                let id: i64 = r.get(0)?;
                // Read the vector in place: copying 256 bytes per row is most of a scan's cost.
                let blob = r.get_ref(1)?.as_blob().map_err(|e| rusqlite::Error::FromSqlConversionFailure(1, rusqlite::types::Type::Blob, Box::new(e)))?;
                let c = embed::cosine(&qv, blob);
                if c < 0.12 {
                    continue;
                }
                if top.len() < CANDIDATES {
                    top.push((id, c));
                } else if let Some((i, _)) = top.iter().enumerate().min_by(|a, b| a.1 .1.partial_cmp(&b.1 .1).unwrap()) {
                    if c > top[i].1 {
                        top[i] = (id, c);
                    }
                }
            }
            top.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap());
            similar = top;
        }

        let mut score: HashMap<i64, (f64, Option<usize>, Option<usize>)> = HashMap::new();
        for (rank, id) in keyword.iter().enumerate() {
            let e = score.entry(*id).or_insert((0.0, None, None));
            e.0 += 1.0 / (RRF_K + rank as f64 + 1.0);
            e.1 = Some(rank + 1);
        }
        for (rank, (id, _)) in similar.iter().enumerate() {
            let e = score.entry(*id).or_insert((0.0, None, None));
            e.0 += 1.0 / (RRF_K + rank as f64 + 1.0);
            e.2 = Some(rank + 1);
        }
        let mut ranked: Vec<(i64, (f64, Option<usize>, Option<usize>))> = score.into_iter().collect();
        ranked.sort_by(|a, b| b.1 .0.partial_cmp(&a.1 .0).unwrap().then(a.0.cmp(&b.0)));
        ranked.truncate(limit);

        let mut hits = Vec::with_capacity(ranked.len());
        for (id, (s, k, v)) in ranked {
            if let Some(memory) = self.get(id)? {
                // What is about the task at hand beats what is about everything.
                let narrow = match memory.scope {
                    Scope::Global => 0.0,
                    Scope::Project => 0.0006,
                    Scope::Task => 0.0012,
                    Scope::Session => 0.0018,
                };
                hits.push(Hit { memory, score: s + narrow, keyword_rank: k, similar_rank: v });
            }
        }
        hits.sort_by(|a, b| b.score.partial_cmp(&a.score).unwrap());
        Ok(hits)
    }

    /// The memories linked to a symbol, file or other target in a project.
    pub fn notes_for(&self, project: &str, target: &str) -> Result<Vec<Memory>> {
        let mut st = self.db.prepare(
            "SELECT DISTINCT m.id FROM memories m JOIN links l ON l.memory = m.id WHERE l.project = ?1 AND (l.target = ?2 OR l.file = ?2) ORDER BY m.updated_ms DESC",
        )?;
        let ids = st.query_map(params![project, target], |r| r.get::<_, i64>(0))?.collect::<std::result::Result<Vec<_>, _>>()?;
        let mut out = Vec::new();
        for id in ids {
            if let Some(m) = self.get(id)? {
                out.push(m);
            }
        }
        Ok(out)
    }

    /// Marks the memories linked to a target as stale, or as current again.
    pub fn mark_stale(&mut self, project: &str, target: &str, stale: bool) -> Result<usize> {
        Ok(self.db.execute(
            "UPDATE memories SET stale = ?3 WHERE id IN (SELECT memory FROM links WHERE project = ?1 AND (target = ?2 OR file = ?2))",
            params![project, target, stale as i64],
        )?)
    }

    /// Every link to a symbol in a project, with the memory it belongs to.
    pub fn symbol_links(&self, project: &str) -> Result<Vec<LinkRef>> {
        let mut st = self.db.prepare(
            "SELECT l.id, l.memory, l.kind, l.project, l.target, l.file, l.commit_sha, l.code_hash, m.stale
             FROM links l JOIN memories m ON m.id = l.memory WHERE l.project = ?1 AND l.kind = 'symbol' ORDER BY l.id",
        )?;
        let rows = st.query_map([project], |r| {
            Ok(LinkRef {
                link_id: r.get(0)?,
                memory: r.get(1)?,
                link: Link { kind: r.get(2)?, project: r.get(3)?, target: r.get(4)?, file: r.get(5)?, commit: r.get(6)?, code_hash: r.get(7)? },
                stale: r.get::<_, i64>(8)? != 0,
            })
        })?;
        Ok(rows.collect::<std::result::Result<Vec<_>, _>>()?)
    }

    pub fn set_link_hash(&mut self, link_id: i64, hash: &str) -> Result<()> {
        self.db.execute("UPDATE links SET code_hash = ?2 WHERE id = ?1", params![link_id, hash])?;
        Ok(())
    }

    pub fn set_stale(&mut self, memory: i64, stale: bool) -> Result<()> {
        self.db.execute("UPDATE memories SET stale = ?2 WHERE id = ?1", params![memory, stale as i64])?;
        Ok(())
    }

    pub fn count(&self) -> Result<i64> {
        Ok(self.db.query_row("SELECT COUNT(*) FROM memories", [], |r| r.get(0))?)
    }

    /// Reclaims space and refreshes the planner's statistics; cheap to run now and then.
    pub fn tidy(&self) -> Result<()> {
        self.db.execute_batch("INSERT INTO memories_fts(memories_fts) VALUES ('optimize'); PRAGMA optimize; PRAGMA wal_checkpoint(TRUNCATE);")?;
        Ok(())
    }
}

fn read_memory(r: &Row<'_>) -> rusqlite::Result<Memory> {
    let scope: String = r.get(1)?;
    let tags: String = r.get(8)?;
    Ok(Memory {
        id: r.get(0)?,
        scope: Scope::parse(&scope).unwrap_or(Scope::Global),
        scope_key: r.get(2)?,
        kind: r.get(3)?,
        title: r.get(4)?,
        body: r.get(5)?,
        source: r.get(6)?,
        source_ref: r.get(7)?,
        tags: tags.split_whitespace().map(str::to_string).collect(),
        created_ms: r.get(9)?,
        updated_ms: r.get(10)?,
        stale: r.get::<_, i64>(11)? != 0,
        links: vec![],
    })
}

/// The SQL that keeps a query to the scopes that apply, with its arguments.
/// Columns are read as `m.` (the memories table).
fn scope_clause(ctx: &Context, all: bool) -> (String, Vec<String>) {
    if all {
        return ("1 = 1".into(), vec![]);
    }
    let mut parts = vec!["m.scope = 'global'".to_string()];
    let mut args = Vec::new();
    for (scope, key) in [("project", &ctx.project), ("task", &ctx.task), ("session", &ctx.session)] {
        if let Some(k) = key {
            parts.push(format!("(m.scope = '{scope}' AND m.scope_key = ?)"));
            args.push(k.clone());
        }
    }
    (format!("({})", parts.join(" OR ")), args)
}

/// Numbers bare `?` placeholders from `start`, so a clause built with plain
/// placeholders can follow others in one statement.
fn renumber(clause: &str, start: usize) -> String {
    let mut out = String::with_capacity(clause.len() + 8);
    let mut n = start;
    for c in clause.chars() {
        if c == '?' {
            out.push_str(&format!("?{n}"));
            n += 1;
        } else {
            out.push(c);
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn note(scope: Scope, key: &str, title: &str, body: &str) -> NewMemory {
        NewMemory { scope: Some(scope), scope_key: key.into(), title: title.into(), body: body.into(), ..Default::default() }
    }

    fn brain() -> Brain {
        Brain::open_in_memory().unwrap()
    }

    #[test]
    fn a_memory_is_stored_and_read_back_with_its_links() {
        let mut b = brain();
        let id = b
            .remember(NewMemory {
                scope: Some(Scope::Project),
                scope_key: "tether".into(),
                kind: "decision".into(),
                title: "Hub keeps history".into(),
                body: "The hub stores every session's history in SQLite.".into(),
                source: "you".into(),
                tags: vec!["Hub".into(), " history ".into()],
                links: vec![Link { kind: "symbol".into(), project: "tether".into(), target: "hub.Hub.commit".into(), file: "server/internal/hub/hub.go".into(), commit: "abc123".into(), ..Default::default() }],
                ..Default::default()
            })
            .unwrap();
        let m = b.get(id).unwrap().unwrap();
        assert_eq!((m.scope, m.scope_key.as_str(), m.kind.as_str()), (Scope::Project, "tether", "decision"));
        assert_eq!(m.tags, vec!["hub", "history"]);
        assert_eq!(m.links.len(), 1);
        assert_eq!(m.links[0].commit, "abc123");
        assert!(!m.stale);
    }

    #[test]
    fn empty_text_and_nameless_scopes_are_refused() {
        let mut b = brain();
        assert!(b.remember(note(Scope::Global, "", "t", "   ")).is_err());
        assert!(b.remember(note(Scope::Project, "", "t", "body")).is_err());
        assert!(b.remember(note(Scope::Global, "", "t", "body")).is_ok());
    }

    #[test]
    fn recall_finds_by_words_and_by_likeness() {
        let mut b = brain();
        b.remember(note(Scope::Global, "", "Tunnel", "cloudflared quick tunnels change address when they restart")).unwrap();
        b.remember(note(Scope::Global, "", "Colours", "the settings screen uses equal columns for theme chips")).unwrap();
        b.remember(note(Scope::Global, "", "Backups", "the hub backs sessions up to the NAS while an app is in use")).unwrap();

        let hits = b.recall(&Query::new("how do tunnel addresses change")).unwrap();
        assert_eq!(hits[0].memory.title, "Tunnel");
        assert!(hits[0].keyword_rank.is_some());

        // No word in common with the note, but its pieces are close.
        let hits = b.recall(&Query::new("restarting tunnels")).unwrap();
        assert_eq!(hits[0].memory.title, "Tunnel");
    }

    #[test]
    fn scopes_decide_who_sees_what() {
        let mut b = brain();
        b.remember(note(Scope::Global, "", "g", "shared deploy habit uses tags")).unwrap();
        b.remember(note(Scope::Project, "tether", "t", "tether deploy goes through ship.sh")).unwrap();
        b.remember(note(Scope::Project, "other", "o", "other deploy goes through make")).unwrap();
        b.remember(note(Scope::Task, "fix-login", "k", "login deploy needs the staging token")).unwrap();

        let mut q = Query::new("deploy");
        q.ctx.project = Some("tether".into());
        let titles: Vec<_> = b.recall(&q).unwrap().into_iter().map(|h| h.memory.title).collect();
        assert!(titles.contains(&"g".into()) && titles.contains(&"t".into()));
        assert!(!titles.contains(&"o".into()) && !titles.contains(&"k".into()));

        q.ctx.task = Some("fix-login".into());
        let titles: Vec<_> = b.recall(&q).unwrap().into_iter().map(|h| h.memory.title).collect();
        assert!(titles.contains(&"k".into()));

        q.all_scopes = true;
        assert_eq!(b.recall(&q).unwrap().len(), 4);
    }

    #[test]
    fn narrower_memories_win_ties() {
        let mut b = brain();
        b.remember(note(Scope::Global, "", "wide", "the release process uses a tag")).unwrap();
        b.remember(note(Scope::Project, "tether", "narrow", "the release process uses a tag")).unwrap();
        let mut q = Query::new("release process tag");
        q.ctx.project = Some("tether".into());
        assert_eq!(b.recall(&q).unwrap()[0].memory.title, "narrow");
    }

    #[test]
    fn forgetting_removes_it_from_search_for_good() {
        let mut b = brain();
        let id = b.remember(note(Scope::Global, "", "secret", "the staging password is hunter2")).unwrap();
        assert_eq!(b.recall(&Query::new("staging password")).unwrap().len(), 1);
        assert!(b.forget(id).unwrap());
        assert!(b.recall(&Query::new("staging password")).unwrap().is_empty());
        assert!(!b.forget(id).unwrap());
        assert_eq!(b.count().unwrap(), 0);
    }

    #[test]
    fn updating_changes_what_it_is_found_by() {
        let mut b = brain();
        let id = b.remember(note(Scope::Global, "", "old", "alpha beta gamma")).unwrap();
        assert!(b.update(id, "new", "delta epsilon zeta", &["greek".into()]).unwrap());
        assert!(b.recall(&Query::new("alpha")).unwrap().is_empty());
        assert_eq!(b.recall(&Query::new("epsilon")).unwrap()[0].memory.id, id);
        assert!(!b.update(9999, "x", "y", &[]).unwrap());
    }

    #[test]
    fn notes_for_a_symbol_and_staleness() {
        let mut b = brain();
        let link = |t: &str, f: &str| Link { kind: "symbol".into(), project: "tether".into(), target: t.into(), file: f.into(), commit: "c1".into(), ..Default::default() };
        let a = b.remember(NewMemory { links: vec![link("hub.commit", "hub.go")], ..note(Scope::Project, "tether", "a", "commit stores items") }).unwrap();
        b.remember(NewMemory { links: vec![link("hub.other", "other.go")], ..note(Scope::Project, "tether", "b", "unrelated") }).unwrap();

        let found = b.notes_for("tether", "hub.commit").unwrap();
        assert_eq!(found.len(), 1);
        assert_eq!(found[0].id, a);
        assert_eq!(b.notes_for("tether", "hub.go").unwrap().len(), 1, "found by its file too");
        assert!(b.notes_for("elsewhere", "hub.commit").unwrap().is_empty());

        assert_eq!(b.mark_stale("tether", "hub.commit", true).unwrap(), 1);
        assert!(b.get(a).unwrap().unwrap().stale);
        let mut q = Query::new("commit stores items");
        q.ctx.project = Some("tether".into());
        q.include_stale = false;
        assert!(b.recall(&q).unwrap().is_empty(), "stale notes can be left out");
        q.include_stale = true;
        assert_eq!(b.recall(&q).unwrap().len(), 1);
        b.mark_stale("tether", "hub.commit", false).unwrap();
        assert!(!b.get(a).unwrap().unwrap().stale);
    }

    #[test]
    fn kinds_filter_and_odd_queries_do_not_break() {
        let mut b = brain();
        b.remember(NewMemory { kind: "decision".into(), ..note(Scope::Global, "", "d", "use sqlite for the brain") }).unwrap();
        b.remember(NewMemory { kind: "note".into(), ..note(Scope::Global, "", "n", "sqlite is fast enough") }).unwrap();
        let mut q = Query::new("sqlite");
        q.kinds = vec!["decision".into()];
        let hits = b.recall(&q).unwrap();
        assert_eq!(hits.len(), 1);
        assert_eq!(hits[0].memory.kind, "decision");
        for odd in ["", "   ", "\"quoted\" OR AND NOT (", "*", "a", "日本語のテスト"] {
            b.recall(&Query::new(odd)).unwrap();
        }
    }

    #[test]
    fn listing_gives_the_newest_that_apply() {
        let mut b = brain();
        b.remember(note(Scope::Global, "", "first", "one")).unwrap();
        std::thread::sleep(std::time::Duration::from_millis(3));
        b.remember(note(Scope::Project, "p", "second", "two")).unwrap();
        b.remember(note(Scope::Project, "q", "hidden", "three")).unwrap();
        let ctx = Context { project: Some("p".into()), ..Default::default() };
        let titles: Vec<_> = b.list(&ctx, false, 10).unwrap().into_iter().map(|m| m.title).collect();
        assert_eq!(titles, vec!["second", "first"]);
    }
}
