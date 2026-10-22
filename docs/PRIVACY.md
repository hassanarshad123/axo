# Privacy principles (internal draft)

> **Draft for the team. Not a published privacy policy.** Hassan must approve the public text before release.

A camera app must earn trust. These rules guide the code. If code breaks one of them, the code is wrong.

1. **Camera frames stay on the Mac.** Each frame is checked in memory and dropped at once.
2. **The camera runs only for short checks** (about 3 seconds each minute), and only when the user is at the Mac and has calibrated. One more short look: after 100 seconds with no keyboard or mouse input, the camera looks for a face or a person for at most 3 seconds, to tell "reading" from "away". While it sees the user, it looks again once a minute. When it sees nobody, it stops until the next input. Never during a call, a break, a pause or on a locked screen.
3. **Progress photos are opt-in.** Off by default. When on: at most 2 a day (1 daily, 1 bad posture), saved only on this Mac in `~/Library/Application Support/Axo/Photos`, only the user can open the folder, left out of Time Machine, no metadata in the file, deleted after 30 days, one button deletes all. A frame is copied only when this switch is on.
4. **No account and no cloud sync.** Settings and history stay on the Mac. The history holds results only (good or slouching, which reminder, done or snoozed, minutes at the Mac), never a picture or a measurement. It is a file in `~/Library/Application Support/Axo`, with iCloud sync off. Each check and reminder event is deleted after 90 days; day totals stay. "Delete history…" in the Progress window deletes all of it.
5. **AirPods motion** is read only during the same short checks. Only head angle is used.
6. **"In a call" detection** only asks macOS whether the mic is running. The app never listens to the mic. The voice coach asks the same question right before each line, and stays quiet while the mic runs.
7. **Anonymous usage counts only.** No names, emails, photos, posture readings or device IDs that point to a person. The user can turn counts off (the setup window and Settings > General). Counts start only after the setup window is done. Only the six events in `UsageSignal` go: app started, reminder done, reminder snoozed, break finished, setup finished, buddy picked. Axo builds each count itself (`UsageReport`), without the TelemetryDeck SDK, so no other field is added. Turning the switch off drops the waiting counts and deletes the random install id (`UsageCounts`).
8. **Network calls are listed here, and only these exist:**

   | Call | Where to | When | What goes |
   |---|---|---|---|
   | Update check (Sparkle 2.10.0) | `https://axo.zensbot.com/appcast.xml`, then the GitHub release file for an update | Once a day while "Check for updates automatically" is on, and on "Check for Updates…" | A normal web request. Sparkle's system profile is off (`SUEnableSystemProfiling: false`). |
   | Usage counts (TelemetryDeck ingest API, no SDK) | `https://nom.telemetrydeck.com/v2/` | At once after one of the six events (offline: with the next one, in memory only) | The event, its kind or buddy id ("locked" for a buddy from a locked pack), app version and build, macOS major.minor, chip type, test-build flag, a random id per launch and the SHA-256 hash of a random install id. Nothing else (`UsageReport`, tested). |

   A new network call needs a new row here and in the public notice first.

## Permissions the app asks for

| Permission | Why | When asked |
|---|---|---|
| Camera | Posture check, presence look | In the setup window, or at the first calibration |
| Motion & Fitness | AirPods head motion | At first AirPods check |
| Notifications | Reminder banners | In the setup window |
