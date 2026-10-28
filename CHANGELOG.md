# Changelog

Each release's section becomes its release notes and the notes the apps show. Keep the heading as `## X.Y.Z`.

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
