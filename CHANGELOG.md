# Changelog

Each release's section becomes its release notes and the notes the apps show. Keep the heading as `## X.Y.Z`.

## 0.17.7

- **Home is a chat app.** It opens on a new chat: a greeting, the folders you work in to pick from, and the message box at the bottom. Tether still picks the folder for you when you don't. A switch at the top, New | Chats, goes to the list of every chat.
- **One side menu, no bottom bar.** On a phone the menu button opens it; on a desktop it sits beside the page and folds away. It holds New chat, Devices, History, Files, Routines and Usage, **Projects** (the folders you continue work in, each with its chats) and **Chats** (everything, one-off questions included).

## 0.17.6

- **Smooth, like a phone.** Lists bounce at their ends, pages slide in and swipe back, switching between Home, Chats, Devices and the rest cross-fades, and chats, files and messages fade in as they are loaded, including the ones you scroll up to. Every page leaves 15% of the screen empty under its last item.
- **Pull down to refresh** on Home, Chats, Devices, History, Files, Usage, Routines and Settings; in a chat, pull the oldest message down.
- **Windows updates through WinSparkle.** The desktop app checks a signed `appcast.xml` on the GitHub release and installs with the setup program, which swaps the app cleanly. Android reads GitHub first and the hub second. Windows apps older than this one still update from the zip, one last time.
- **The notification tunnel can run in Docker.** The hub gives the tunnel to an on-demand-tunnel-cf service (`-tunneld`), asks it for the current address and sends that to every app, so the address stays in sync as it changes.

## 0.17.5

- **Notifications.** Send a prompt and leave: your phone is told when Claude finishes, when it needs an approval or has a question, or when a session fails. Turn it on under Settings, Notifications (Finished, Needs you, Failed, and a test button). An Android service listens quietly while the app is closed and stays silent while the app is on screen.
- **Reached with or without Tailscale.** The hub can open a Cloudflare tunnel (`-notify-tunnel`) that serves only notifications, with a token that opens nothing else, and tells your apps its address as it changes. Through the tunnel only titles travel, not what Claude said; the full text comes over Tailscale.
- **A Files view.** Chat beside the files Claude is changing: a tab for each file and its changes as live, syntax-highlighted diffs that follow the newest one. It replaces Split. On a phone the three views are one button in the header.
- **A better Terminal view.** The transcript draws tables with box characters, frames and colours code by language, shows each edit as a coloured diff, a write as its new text, and to-dos as a checklist.

## 0.17.4

- **A more reliable update on Windows.** The release carries a small updater program that swaps the app for the new version, checks the new version comes up, and puts the old one back if it does not. It no longer depends on a script starting after the app exits.
- **Check for updates** in Settings, with the app and hub versions.
- **Chat, Split and Terminal views** of a conversation: the same timeline drawn as chat, as a terminal transcript, or both side by side.
- **Files a session delivers** (a build, an export) show as cards above the composer with Download, and a program says it is one. A session's `.tether/out/` folder is delivered to its chat.
- **Delete a chat** from its menu; the sessions it held stay.
- **First run finds your hub.** A new install looks for the hub among the devices on your Tailscale network (the desktop can list them; most devices don't run Tether, so only the ones that answer are shown), remembers hubs it has connected to, and connects by tap, pairing code or QR code.
- **Settings folds away.** Devices, Workspaces and Codebases are collapsible sections with counts, so the page stays short.
- **Better matching of where a chat runs.** The folders you work in most break ties between machines with the same repo, your home and app-data folders are no longer treated as projects, and suggested workspace folders come from where your projects really are.
- **Each device has a checklist** from its agent: Claude Code found, hooks installed, Tether's tools registered, git, tmux and a writable data folder, with what to do about anything missing.

## 0.17.3

- **Back works like a phone.** Switching between Home, Chats, Devices and the rest no longer piles up history; Back closes what you opened, then goes Home, then leaves. A chat, Settings, Home and Back no longer reopens the chat.
- **A new look, starting with Home.** A terminal-style start box with your pinned skills as `/skill` chips, run cards with step bars for what is working, a card for each chat, small mono labels, and the Tether theme as the default dark look. The chat box is a prompt too. Text on the accent colour is dark where white would be hard to read.
- Destinations on wide screens no longer show a back arrow.

## 0.17.2

- **Fix: the Windows app now applies its update.** After Restart to update, the helper that swaps in the new version never started, so the app came back on the old version and offered the update again. It now starts the right way, and the update screen no longer loops.

## 0.17.1

- **One command ships a release** from your own machine: `make ship ARGS=--patch` tests, builds the hub, agents, APK and Windows app, and deploys over ssh with the usual backup and rollback. Apps and agents then update themselves.
- **Files reach the chat.** Anything a session leaves in `.tether/out/` is delivered as a file you can download, and a chat's Files list is available from the hub.
- **Machines say what they can build** (Flutter, Android SDK, Docker and so on), shown on the device card and in the lead's prompt.
- **Skills are offered by fit.** A new chat is offered the three skills that match its request instead of all of them, and you can pin skills to Home.
- **An audit log** of tool calls and skill decisions on the hub.
- **Home, Chats and History** are separate places, the phone bar gets More, Inter and JetBrains Mono are built in, and a new Tether look is available under Appearance.

## 0.17.0

- **Updates in the app.** The app checks for a new release when it starts and every few hours, and the hub announces one as soon as it has it. A banner shows the release notes, with Update and Skip this version. On Android the update downloads, is checked, and opens the installer; on Windows it is applied when the app restarts. A release can require an update from versions that are too old.
- **Agents update themselves** through the hub when they're idle. They keep the previous binary and go back to it if the new one can't reach the hub.
- **Releases are built and deployed by CI.** Tagging `vX.Y.Z` tests, builds the hub, agents, tetherctl and the signed APK on the hub's machine and the Windows app on GitHub. The release is published with checksums and `latest.json`, and the hub's machine is deployed with a backup and automatic rollback. `make release` does the same by hand.

## 0.16.0

- **Chats.** The app works like a chatbot: chats with titles you can rename, a history, and the sessions behind each chat linked to it, including ones Claude starts on other machines.
- **Where a chat runs** is matched from what you write, picked by you, or worked out by Claude, and can be changed; the conversation carries over.
- **New navigation:** Chats and Monitor, a redesigned sidebar, an icon rail on tablets, and a bottom bar on phones.
- A message sent from the app no longer shows twice, and pasted text no longer shows its `<pasted_content>` tags.

## 0.15.0

- Prompt cards for dialogs on screen, a persistent outbox for queued messages, permission modes, a clearer interrupt, the devices screen in install order, and background backups while an app is in use.
