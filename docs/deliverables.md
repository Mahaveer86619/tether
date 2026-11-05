# Deliverables: asking for something and getting the file

Status: plan. Product view: [v1-spec.md](v1-spec.md#f-files-results-and-guides). The pieces it stands on exist: the artifact store, resumable downloads, signed links, file hooks, generated pages. What is missing is the way a thing the assistant *makes* reaches the chat as a file you can take.

## The scenario

From the phone: "build a new APK of the app from the laptop." The lead hands the job to a session on the laptop, which builds it; the APK appears in the chat as a card with **Download** and **Install**. The same path serves a CSV of failing rows, a PDF report, a spreadsheet, a zip, a screenshot, a log.

## What happens today

- A file the assistant writes or reads with its file tools is uploaded by the agent's hook as an artifact linked to that tool call, and shows on the tool card.
- A file made by a command (a build, an export script) is not seen by anything: the assistant knows where it put it, Tether doesn't.
- There is no place that gathers a chat's files.

## The design

### 1. Two ways a file becomes a deliverable

- **`present_file(path, note)`**, a hub tool the assistant calls: "I made this, the user wants it." The agent on that machine reads the file, uploads it as an artifact with origin `result`, and the hub puts a result item in the chat. This is the main path; the lead prompt and the task prompt tell the assistant to use it whenever it produces a file for the user (a build, an export, a report). Works for any file anywhere on the machine.
- **A drop folder**, `<cwd>/.tether/out/`: anything placed there is delivered automatically, the way pages under `.tether/pages/` are. For scripts that can't call a tool.

### 2. What the file carries

`Artifact` gets: `kind` (apk, csv, pdf, xlsx, zip, image, text, other, from the extension and a sniff), `description` (one line from the assistant), `made_by_node`, the producing session and tool call, and the turn it belongs to. For an APK the agent reads the package name, version name and code, and whether it is signed with a debug key; the card shows them ("com.example.app 0.18.0 (1800), debug-signed") so an install is informed.

### 3. How it shows in the chat

- A **file card** on the message or tool call that produced it: icon, name, size, machine, time, **Download**, **Open or Preview** (F3 of the spec), **Share**, and **Install** for an APK on Android (reusing the update installer's path, with the "allow installs from Tether" step).
- At the end of a turn that made files, one **result card** gathers them. The hub derives it: when a turn ends, the artifacts with origin `result` created in it are linked to a result item.
- Nothing waits for the session to end: the card appears when `present_file` returns.

### 4. The chat's Files panel

`GET /api/v1/chats/{id}/artifacts` returns every artifact of every session in the chat, newest first, with origin (sent or made), kind and size, paged. The app's Files panel is two tabs over it ("You sent", "Made for you") with a type filter and name search. The global Files screen stays for everything on the hub.

### 5. Getting it to the device

Downloads use the existing machinery: resumable with `Range`, hash-checked, in the background with a progress notification, pause and resume, saved to a chosen folder (Android: the app's download location and the system's Downloads through MediaStore; Windows: a folder the person picks once). The hub keeps the copy, so a file stays downloadable when the machine that made it is asleep.

### 6. Knowing which machine can build what

"Build the APK" must go to the machine with the Android toolchain. Agents report **capabilities** (the doctor's checks: Flutter, Gradle and the Android SDK, Go, Docker, a Linux terminal multiplexer, the assistant's version) in the node's status. The lead's prompt lists them next to each machine ("laptop (windows): flutter, gradle, android-sdk"), and target choice for Auto uses them. No guessing, and no asking the person which machine builds.

### 7. Safety

- An installer or executable is flagged on its card ("a program") and never opens by itself.
- An APK's signature is shown; installing one signed differently from the installed app says it will replace it only if the signatures match, and otherwise explains.
- Sizes are capped by the hub's free disk, said plainly before an upload starts.
- Retention follows the session; a card for a removed file says so.
- Signed links expire; the app downloads with its token.

## Build order

1. `present_file` and the prompt text that tells the assistant to use it; the agent uploads; a file card in the chat. (End to end on text and CSV first, then big files.)
2. The drop folder.
3. `kind` and APK metadata; **Install** on Android.
4. The result card at the end of a turn.
5. The Files panel and `GET /chats/{id}/artifacts`.
6. Capabilities in the node status and in the lead's prompt.
7. Download destinations and the tray.

## Tests

- A fake agent with a file on disk: `present_file` uploads it, the hub records `result`, the chat shows the card, a second call with the same file doesn't duplicate it.
- The drop folder delivers a file once, ignores files being written, and ignores its own temp files.
- APK metadata is parsed from a small sample APK; a debug-signed one is flagged.
- The chat artifacts endpoint pages, filters by origin, and includes files from every session of the chat.
- A 2 GB file downloads, is interrupted, and resumes with the same hash.
- The lead's prompt lists capabilities; Auto prefers the machine that has the toolchain a request names.

## Open

- Confirm before a large download on mobile data?
- Where downloads go by default on each platform, and whether the person can choose.
- Whether `present_file` may also take a URL or a hub path for a file that is already stored.
