# Daily use (milestone 7)

Use Axo every work day for 1 to 2 weeks. Note what annoys you or feels wrong. Claude then fixes it and tunes the posture limits from your real history.

## Install or update

1. Run `make install` in the repo (or ask Claude to do it).
2. Axo opens from `/Applications/Axo.app`. The setup window opens at the first start.
3. In the setup window, allow the camera and notifications, and calibrate (sit well for 5 seconds).
4. Open **Settings > General** and turn on **Open at login**.

`make install` signs the app with your Apple Development certificate. So macOS keeps the camera permission after each update. This build runs on your Mac only.

## What to watch

| Area | Good | Report it when |
|---|---|---|
| Posture nudges | A nudge comes when you slouch for a while | A nudge comes while you sit well, or never comes when you slouch. Try **Settings > Posture > Sensitivity** first. |
| Calls | No reminder, nudge or voice while an app uses the mic (Zoom, Meet, Teams, a voice note) | Anything shows or speaks in a call. This is the worst failure. |
| Reminders | Stand, eyes, stretch and water come at sensible times | They come too often, too rarely, or while you are away |
| Full-screen breaks | The notice comes first, and Esc held 3 s always gets you out | You feel trapped, or a break covers something important |
| Reading vs away | Reminders keep their time while you read without typing | Axo thinks you are away while you sit at the Mac |
| Voice | Calm, at a good volume, never talks over itself | It is too loud, too often, or speaks at a bad moment |
| Camera light | Short flashes, about once a minute while you work | The light stays on, or flashes while you are away |
| Progress | The score, streak and level feel fair | A good day shows a bad score, or the level jumps |
| Battery and speed | You do not notice Axo | The Mac feels slower, or Axo shows high CPU in Activity Monitor |

## How to report

Tell Claude in one line: **"Axo: what happened, at about what time"**. For example: "Axo: posture nudge at 3:40 pm while I sat straight".

Claude can read these on your Mac:

- The app log of the last hours: `log show --last 3h --predicate 'subsystem == "com.hassanarshad.axo"'`.
- Your posture and reminder history: `~/Library/Application Support/Axo/History.store`. It holds results only (good or slouching, reminder done or snoozed), never a picture.

## Known gaps

- The duo in pack 1 has no grown-up forms and no blink yet.
- Buddies with little color (Bit, Nubo, Hoot, Usa) barely change with a color choice.
- The menu bar icon does not show "paused".
- Axo finds a call only from "an app uses the mic". It never listens. This is not yet tested in a real Zoom, Meet or Teams call. Please test it in your first week.
- In a call with the mic muted, some apps stop the mic. Then Axo can think the call ended.

## After 1 to 2 weeks

Claude reads the history, tunes the posture limits and the reminder times, and fixes what you reported. Then the release steps in `docs/RELEASE.md` start.
