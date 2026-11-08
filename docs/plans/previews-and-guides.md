# Previews in the chat, and interactive guides

Status: plan, nothing built beyond the base it stands on (the artifact store and generated pages). Two features that share one idea: **the chat shows what it can, and hands the rest to a better surface**, for you and for the analysis of attachments and results.

## Previews in the chat

### What you get

Files and results appear in the conversation as they are made, and you can look at them without leaving it. A preview is part of the timeline, not a separate screen: it opens in place (a card that expands), as a sheet on a phone, and beside the chat on a wide window.

| Kind | What the chat shows | Download |
|---|---|---|
| Images | The picture, tap to zoom | Yes |
| Text, Markdown, logs | The first lines, expand to read, search inside | Yes |
| Code, JSON, YAML, diffs | Highlighted, line numbers, expand | Yes |
| CSV and TSV | A table: first rows, sortable columns, row count | Yes |
| HTML pages | Opens as an interactive guide (below) | |
| Audio and video | A player | Yes |
| PDF, Word, Excel, PowerPoint, archives, binaries | **A file card only**: icon, name, type, size, who made it and when | **Yes, straight from the chat** |

Office and PDF files are not previewed. They appear in the chat as files with a download button, so a generated report or spreadsheet reaches you the moment it exists, over Tether, with no hunting through folders. A thumbnail of the first page may come later; it is not needed for the feature to be useful.

### Where things come from

- Attachments you send: shown on your message (already linked to it).
- Files Claude writes or reads: the artifact store already records them with the tool call that made them; the card appears on that tool card and, for a file Claude calls its result, at the end of the turn.
- A **result card** at the end of a turn that made files: "3 files made" with each as a card. Built from the artifacts linked to the turn; no new protocol.

### For analysis

Previews are for you. For Claude, an attachment is already a path in the session folder and an id in the store, and `read_artifact` pages through text. What changes is that the preview and Claude work from the same artifact: when you point at a preview ("what's wrong with row 12?"), the message carries the artifact id and, for a table, the row or range, so Claude doesn't have to find it.

### Design

- **Renderer per kind**, chosen by mime type and extension, behind one `ArtifactPreview` widget with a size budget: text over 256 KB, tables over 5,000 rows and images over 20 MB show their start and offer the download.
- **Loads lazily**, as the card scrolls into view, and caches by sha256.
- **Same link as downloads**: the signed link or the token header, resumable. A preview is a download that stops early.
- **Safe**: no HTML or script from a file is run in the app; HTML goes only to the guide viewer.
- **Accessible**: every preview has a text alternative (name, type, size) and works with the keyboard on desktop.

### Build order

1. File card with type icon, size and Download in the chat, on attachments and results. (Mostly exists in `ArtifactStrip`; make it the one card.)
2. Image zoom, text and code expand, Markdown.
3. Table preview for CSV.
4. Audio and video.
5. Result card at the end of a turn.
6. Pointing at a row or region in a message.

## Interactive guides

### What they are

When you ask for something that is better *explored* than *read*, Claude builds a small website and the chat gives you a button to open it. Your example: a wiring design for an IoT project, where a chat can't show the connections properly but an interactive diagram can (click a pin to see what connects to it, highlight a net, toggle the power rails). The feature is wider than that:

| Guide | What it is for |
|---|---|
| Wiring and circuit diagrams | Pins, nets, parts list, highlight a connection, notes per part |
| Architecture and flow maps | Click a box to see what it does and what it talks to |
| Runbooks and checklists | Steps with checkboxes that remember where you are, commands to copy |
| Data explorers | A CSV or query result with filter, sort, group and a chart |
| Comparisons and calculators | Options side by side, sliders that change the result |
| Timelines and plans | Milestones, dependencies, what's blocked |
| Explainers and quizzes | A concept shown step by step, with questions |
| Dashboards of a long job | The sync status page: machines, rows, speed, what's stuck |

### How it works

It builds on **generated pages** ([plan.md](plan.md#generated-pages)): Claude writes a folder under `.tether/pages/<name>/` with `index.html` as the entry; the agent uploads it as artifacts; the hub serves it at `/p/<token>/...` with a sandboxing Content-Security-Policy.

What this adds:

1. **A page card in the chat**, where the page was made: its title, what it shows, "Open" and "Copy link". Not a link buried in text.
2. **An opener.** On the desktop it opens in the browser, later in a pane beside the chat; on a phone it opens in the browser, later in an in-app view. It needs the hub reachable, which is the tailnet; if Tailscale is down the card says so and offers to bring it up ([app.md](../architecture/app.md#tailscale-in-the-background)).
3. **A way for Claude to know when and how.** The hub's MCP instructions get a short guide: *when the user asks for an interactive guide, diagram, explainer or explorer, build a page*; how to lay it out, what it can and can't do, and a `present_page` tool that puts the card in the chat (name, title, one line).
4. **A small shared kit, hosted by the hub**: one stylesheet in Tether's look (palettes, light and dark), and a few helpers for the common parts (a diagram canvas with pan, zoom and click, a table with sort and filter, step checklists with saved state, copy buttons). Pages link to it with a relative path, so they look like Tether and a page stays small.
5. **Versions.** Asking for a change makes a new version of the same page; the card shows the latest and the history is kept, so a link you shared keeps working.
6. **Saving.** A page is kept with the chat; "Keep" saves it to the library (Files → Pages) so it outlives the session's retention.

### Safety

- The page runs in a sandbox as an opaque origin; it can't call the hub's API or see tokens.
- It must work with **no network**: no CDN scripts, fonts or images from outside. The kit is served by the hub. The sandbox blocks the rest.
- Links are signed and expire; a link can be revoked by deleting the page.
- The page stores nothing but its own state in the browser.

### Where it is not allowed to go

- It is not an app builder: no accounts, no server code, no database.
- It does not talk back to Claude (a later idea: a button in a page that sends a message into the chat).

### Tests

- A page check that fails the build of a page for external resources, missing entry file or an oversized folder, and that the sandbox header is present.
- Rendering of the page card, and of its states: building, ready, hub unreachable, page deleted.
- A golden page for each guide type in the kit, opened headless, asserting what the diagram shows for a known wiring input.

### Build order

1. Page card in the chat, with Open, Copy link and the unreachable state.
2. The MCP guide and `present_page`.
3. The shared kit: stylesheet first, then the diagram canvas, then table and checklist.
4. Versions and Keep.
5. In-app viewer (a web view) on both platforms, then side-by-side with the chat on wide screens.
6. Pointing from a page into the chat.

## Open questions

- Does the phone get an in-app web view, or is the browser enough? The browser is simpler and already works; a web view keeps you in the app.
- How much of the kit is worth building before real guides show what is missing? Start with the stylesheet and the diagram, then follow use.
- Should a guide be able to export itself (PDF or PNG of the diagram)?
