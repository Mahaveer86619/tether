//! The memories that apply to a session, as the markdown file it reads first.

use crate::store::{Brain, Context, Memory, Result, Scope};

/// Longest a memory's text is allowed to run in the brief; the rest is a `recall` away.
const BODY_CHARS: usize = 600;

/// Sections for global, project, task and session memories, newest first,
/// each memory with where it came from and what it is linked to.
pub fn brief(brain: &Brain, ctx: &Context, per_section: usize) -> Result<String> {
    let all = brain.list(ctx, false, 500)?;
    let mut out = String::from("# What you already know\n\nMemories that apply to this work, newest first. Ask for more with `recall`.\n");
    let mut wrote = false;
    for (scope, heading) in [(Scope::Task, "This task"), (Scope::Session, "This session"), (Scope::Project, "This project"), (Scope::Global, "Always")] {
        let items: Vec<&Memory> = all.iter().filter(|m| m.scope == scope).take(per_section).collect();
        if items.is_empty() {
            continue;
        }
        wrote = true;
        let key = items[0].scope_key.as_str();
        if key.is_empty() {
            out.push_str(&format!("\n## {heading}\n\n"));
        } else {
            out.push_str(&format!("\n## {heading}: {key}\n\n"));
        }
        for m in items {
            out.push_str(&entry(m));
        }
    }
    if !wrote {
        out.push_str("\nNothing yet.\n");
    }
    Ok(out)
}

fn entry(m: &Memory) -> String {
    let title = if m.title.is_empty() { first_line(&m.body) } else { m.title.clone() };
    let mut meta = vec![m.kind.clone()];
    if !m.source.is_empty() {
        meta.push(format!("from {}", m.source));
    }
    if m.stale {
        meta.push("STALE: what it is about has changed".into());
    }
    let mut s = format!("- **{}** ({}) [#{}]\n", title, meta.join(", "), m.id);
    for line in clip(&m.body, BODY_CHARS).lines() {
        s.push_str(&format!("  {line}\n"));
    }
    for l in &m.links {
        let at = if l.file.is_empty() { String::new() } else { format!(" in {}", l.file) };
        s.push_str(&format!("  - about {} `{}`{at}\n", l.kind, l.target));
    }
    s
}

fn first_line(s: &str) -> String {
    clip(s.lines().next().unwrap_or(""), 70)
}

fn clip(s: &str, max: usize) -> String {
    if s.chars().count() <= max {
        return s.to_string();
    }
    let cut: String = s.chars().take(max).collect();
    format!("{}…", cut.trim_end())
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::store::{Link, NewMemory};

    fn add(b: &mut Brain, scope: Scope, key: &str, title: &str, body: &str) -> i64 {
        b.remember(NewMemory { scope: Some(scope), scope_key: key.into(), title: title.into(), body: body.into(), source: "you".into(), ..Default::default() }).unwrap()
    }

    #[test]
    fn an_empty_brain_says_so() {
        let b = Brain::open_in_memory().unwrap();
        let md = brief(&b, &Context::default(), 5).unwrap();
        assert!(md.contains("Nothing yet."));
    }

    #[test]
    fn sections_follow_the_context_narrowest_first() {
        let mut b = Brain::open_in_memory().unwrap();
        add(&mut b, Scope::Global, "", "habit", "always run the tests");
        add(&mut b, Scope::Project, "tether", "deploys", "ship.sh does it");
        add(&mut b, Scope::Project, "other", "hidden", "not this one");
        add(&mut b, Scope::Task, "fix-login", "token", "needs the staging token");
        let ctx = Context { project: Some("tether".into()), task: Some("fix-login".into()), session: None };
        let md = brief(&b, &ctx, 5).unwrap();
        let task = md.find("## This task: fix-login").unwrap();
        let project = md.find("## This project: tether").unwrap();
        let global = md.find("## Always").unwrap();
        assert!(task < project && project < global);
        assert!(!md.contains("hidden"));
        assert!(md.contains("**token** (note, from you)"));
    }

    #[test]
    fn stale_notes_are_marked_and_links_shown() {
        let mut b = Brain::open_in_memory().unwrap();
        let id = add(&mut b, Scope::Project, "tether", "commit", "commit stores items");
        b.remember(NewMemory {
            scope: Some(Scope::Project),
            scope_key: "tether".into(),
            body: "second".into(),
            links: vec![Link { kind: "symbol".into(), project: "tether".into(), target: "hub.commit".into(), file: "hub.go".into(), commit: String::new(), ..Default::default() }],
            ..Default::default()
        })
        .unwrap();
        b.mark_stale("tether", "hub.commit", true).unwrap();
        let md = brief(&b, &Context { project: Some("tether".into()), ..Default::default() }, 5).unwrap();
        assert!(md.contains("STALE"));
        assert!(md.contains("about symbol `hub.commit` in hub.go"));
        assert!(md.contains(&format!("[#{id}]")));
    }

    #[test]
    fn long_text_is_clipped() {
        let mut b = Brain::open_in_memory().unwrap();
        add(&mut b, Scope::Global, "", "long", &"word ".repeat(400));
        let md = brief(&b, &Context::default(), 5).unwrap();
        assert!(md.contains('…'));
        assert!(md.len() < 1500);
    }
}
