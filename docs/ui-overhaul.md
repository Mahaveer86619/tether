# UI overhaul (before 1.0)

Status: plan. The app grew feature by feature, so its screens are consistent in code but uneven in look and feel. Before 1.0 every screen gets one pass against the same rules. This page is the checklist, so the work can go screen by screen on your say.

## How we do it

One screen at a time, in this loop:

1. **You** send a screenshot (phone and desktop) and what bothers you, or say "next screen".
2. **I** write down what I'll change against the rules below, and anything I think is wrong that you didn't mention.
3. **I** change it, add or update a widget test for the behaviour (and a screenshot check where the look matters), and run the app on the Windows build.
4. **You** look at it on the phone and the desktop. Anything off goes back to step 1 for that screen.
5. The screen's row in the table below is ticked, and its entry in [app.md](app.md) is brought up to date.

Nothing here changes what a feature does. A behaviour change goes through [features.md](features.md) first.

## The rules

These come from what you've asked for so far. Add to them as you see things.

1. **Chat first.** The home is a box to say what you want, then what's running, then your chats. Sessions are never a starting point; they open from the chat that owns them.
2. **Say what it does, not how.** A card's header is the short name of the action (`go test ./internal/hub +1`), with the detail one tap away. No raw commands, paths or ids as titles.
3. **Nothing is cut off and nothing stops you scrolling.** Every card, dialog and sheet can be taller than the screen; each scrolls inside a bound, and the rest of the screen stays visible.
4. **Selection works everywhere text is.** Every piece of text you'd want to copy or quote can be selected, and the highlight is visible on every palette.
5. **One thing at a time.** Questions, approvals and forms step through; a long list of options is never one wall.
6. **Work you started keeps going.** An upload, a draft, a download continues when you leave the screen, and its state is visible from where you are.
7. **Say what is happening in the background.** Connecting, starting Tailscale, updating, syncing: a slim banner or a line, never a silent wait and never a modal.
8. **Every state is designed.** Loading, empty, error, offline and partial each have a screen, with one clear next action.
9. **Same thing, same look.** One pill, one card, one empty state, one banner, one sheet. A new screen is built from these, not beside them.
10. **Phone, tablet and desktop are all first class.** The layouts in [app.md](app.md#views) stay; each screen says what it does at 400, 800 and 1400 px.
11. **Copy is plain.** Short sentences, no jargon, the same word for the same thing (chat, task, routine, skill, device).
12. **Colour carries meaning.** Accent is for what you can act on, amber for what needs you, green for done, red for failed; never colour alone.

## Screens

Tick a row when it has had its pass. "Known" is what we already know is wrong or wanted.

| Screen | Files (`app/lib/presentation/`) | Known | Pass |
|---|---|---|---|
| Shell: sidebar, rail, bottom bar, headers, banners | `home/shell.dart`, `nav/` | Sidebar still lists a Projects tree; "New chat" button duplicates the Home box; banner order (Tailscale, update) | [ ] |
| Home | `chats/chats_page.dart`, `chats/new_chat_page.dart`, `home/monitor_page.dart` (LiveSections), `home/cards.dart` | The start box is tall on a phone; Needs-you and Running cards compete with the chat list; search and Archived chip placement | [ ] |
| New chat box and target picker | `chats/new_chat_page.dart`, `chats/target_picker.dart` | Uploads in the foreground; the target chip is easy to miss | [ ] |
| Chat / session screen | `chats/chat_page.dart`, `session/session_page.dart`, `session/session_bloc.dart` | Run card not built; the header holds title, target, tasks, menu in three rows; Tasks strip styling | [ ] |
| Timeline items | `widgets/timeline_item_view.dart`, `widgets/markdown_view.dart`, `widgets/tool_card.dart`, `widgets/todo_checklist.dart` | Tool groups ("Ran N steps") need the same short names; table and code block overflow on narrow screens | [ ] |
| Composer | `widgets/prompt_box.dart`, `session/session_page.dart` (Composer) | Attachment chips for pending, uploaded and failed files look different; the full editor | [ ] |
| Approvals, questions, prompts, terminal dialogs | `session/question_card.dart`, `session/prompt_card.dart`, `session/session_page.dart` (ApprovalCard), `session/terminal_sheet.dart`, `session/mode_picker.dart` | Question card now steps one by one; the other cards still list everything | [ ] |
| Devices and a device's page | `home/devices_page.dart`, `home/session_navigator.dart` | Install-order layout is dense; a device's sessions list | [ ] |
| Activity | `home/activity_page.dart` | | [ ] |
| Files and Pages | `artifacts/files_page.dart`, `artifacts/pages_view.dart`, `artifacts/artifact_widgets.dart` | No inline preview ([previews-and-guides.md](previews-and-guides.md)); page opener | [ ] |
| Routines and Skills | `routines/` | New; step names and the review dialog need a pass | [ ] |
| Usage | `usage/usage_page.dart` | Overflow on narrow screens fixed once; charts are plain bars | [ ] |
| Settings | `settings/settings_page.dart`, `settings/appearance_picker.dart`, `settings/pairing_widgets.dart`, `settings/codebases_section.dart`, `settings/workspaces_section.dart` | One long page; pairing, appearance, codebases and workspaces want their own sections | [ ] |
| First run and connect | `settings/settings_page.dart` (setup) | Scan QR, address and code, token: three paths on one screen | [ ] |
| Update banner and forced update | `update/` | | [ ] |
| Tailscale banner | `tailscale/` | New | [ ] |
| Theme: palettes, type scale, spacing, selection colour | `theme/` | Selection colour set explicitly; type scale and spacing are ad hoc per widget | [ ] |

Dead code to remove in the pass: `new_session/` (the old new-session sheet, no entry point since Home became the start box).

## Shared parts to settle first

Do these before the screens, so the screens use one set:

- **Type scale and spacing tokens** instead of per-widget sizes (`TextStyle(fontSize: 13.5)` is everywhere).
- **Pill, Chip, Card, Banner, Sheet, Dialog, EmptyState, ErrorState, SectionLabel** in `widgets/common.dart`, each with one look.
- **A step bar and a tile** for stepping through choices (the question card has the first version).
- **Run card** ([below](#run-card)).
- **Preview** and **page card** from [previews-and-guides.md](previews-and-guides.md).

## Run card

From your video: a rounded dark card in the chat while a session works.

- Header: a spinner, the icon of the current tool, a present-tense label ("Editing src/billing/invoice.ts") and an elapsed timer.
- Status row: model name, "Step N of M", a segmented progress bar from the to-dos.
- Step list: the last four or five steps, finished ones in past tense with durations, the current one dimmed.
- Buttons: Pause, Stop, Open run.
- When done: a green check and "Done in 13s · 6 files changed", Pause and Stop gone.

It reads from the session's tool events and to-dos; no protocol change is needed. The Tasks strip in a chat uses the same card for each task.

## Definition of done for 1.0 UI

- Every row above ticked.
- Every screen checked at 400, 800 and 1400 px with the longest realistic content (a 3-question card, a 60-step run, a 40-character chat title, a device with 12 sessions).
- No `RenderFlex overflowed` in the widget tests.
- All text selectable where it should be; contrast checked on every palette in light and dark (the Tether palette has a test; the older ones do not meet 4.5:1 everywhere).
- The structure and decisions in [ui-design.md](ui-design.md) are built, phase by phase.
- [app.md](app.md) describes what is there, and [features.md](features.md) agrees.
