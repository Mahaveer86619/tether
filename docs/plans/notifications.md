# Notifications

Status: plan. Product view: [v1-spec.md](../product/v1-spec.md#i1-notifications). Today only two things notify: an update being available and a large download's progress. Nothing tells you the assistant needs you.

## What must be told

| Kind | When | Urgency | Actions |
|---|---|---|---|
| Needs you | An approval or a question arrives | High | Allow, Deny (approvals); Answer (opens the card) |
| Finished | A chat or task ends a turn, fails, or waits for input | Normal | Open |
| Ready | A file the assistant made is ready | Normal | Download, Open |
| Something is wrong | A device goes offline; the hub is unreachable for a while; a skill keeps failing | Normal | Open the device or skill |
| Update | A release is out (exists) | Low | Update, What's new |

A notification is cleared when the thing is answered or seen elsewhere (on another device, in the terminal). One notification per thing: a retry or a second device does not double it.

## The hard part: reaching a sleeping phone

An Android app that is closed holds no connection to the hub, and the hub can only be reached over the private network. Options:

| Path | How | Good | Bad |
|---|---|---|---|
| **Foreground service** | The app keeps its hub connection alive in a service with a small standing notification | Simplest; no extra service; instant; works over the private network | Battery cost; Android may still stop it; a standing notification |
| **UnifiedPush with a self-hosted relay** (ntfy on the hub) | The hub posts to a relay; a distributor app on the phone wakes Tether | No standing connection from Tether; the roadmap's original choice | A second app on the phone; the relay must be reachable (private network again, or public) |
| **A cloud push service** | The hub tells a provider, which wakes the phone | Reliable | A third-party cloud, which is exactly what Tether avoids; rejected |

**Proposal:** build the foreground service first, as an opt-in setting ("Stay connected so I'm notified", on by default once notifications are allowed), with the standing notification as quiet as Android allows. Keep the delivery code behind one interface so the relay can be added later without touching what notifications say. The owner decides the trade-off (see open questions).

Windows: toasts while the app is running; the app can minimise to the tray and start with Windows so it stays running. No relay needed.

## How it works

- **Hub:** an event (approval created, question asked, turn ended, file ready, device offline) goes through the *rules*: kind on or off, quiet hours, which devices, content or no content. The preferences are stored on the hub, per device, and synced like appearance.
- **Frame:** a `Notify{id, kind, title, body, session, chat, actions, clears}` goes to every connected app that should show it. An app that is in the foreground on that chat shows nothing (it is already visible).
- **App:** the foreground service or the running app turns a frame into a system notification with its actions; Allow and Deny call the same API the card does, with the device token, without opening the app. `clears` removes a notification when its subject is resolved elsewhere.
- **Privacy:** "Claude needs you" with no detail is the lock-screen default; the person can show detail.

## Build order

1. Notification rules and preferences on the hub; the `Notify` frame; tests with a fake app.
2. Windows toasts and tray.
3. Android foreground service, channel setup, permission flow, the "test notification" button.
4. Actions from the notification (Allow and Deny), clearing.
5. Quiet hours and per-device choice.
6. The push relay behind the same interface, if the foreground service proves too costly.

## Tests

- Each event kind produces exactly one notification for the right devices and none when muted or in quiet hours.
- A resolved approval clears its notification on every device.
- Allow from a notification reaches the hub and the session continues; Deny likewise.
- A device that was offline gets only the notifications still relevant when it reconnects, not a flood.
- Content hidden on the lock screen shows no session or command text.

## Open

- Foreground service battery cost versus a relay: acceptable?
- Notify for every finished turn, or only for long ones (over some seconds)?
- Group notifications per chat?
