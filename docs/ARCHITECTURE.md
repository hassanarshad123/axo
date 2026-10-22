# Architecture

## Tech stack

| Part | Tool | Why |
|---|---|---|
| Language | Swift 6 (strict concurrency) | Apple's language. Safe threads by default. |
| UI | SwiftUI + a little AppKit | SwiftUI for views. AppKit for the notch window and the menu bar. |
| Posture (camera) | AVFoundation + Vision `VNDetectHumanBodyPoseRequest` | Runs on the Mac. No cloud, no cost per use. |
| Posture (AirPods) | CoreMotion `CMHeadphoneMotionManager` | macOS 14+. Head pitch from AirPods Pro/Max. |
| Away / in a call | CoreGraphics idle time, CoreAudio "mic in use", NSWorkspace sleep and lock events | No extra permissions. |
| Notifications | UserNotifications | Normal Mac banners. |
| Open at login | ServiceManagement `SMAppService` | Apple's current way. |
| Settings | `UserDefaults` (JSON) | Simple. |
| History | SwiftData (`History` module), file on this Mac, CloudKit off | Apple's own store. Versioned schema from day one. |
| Charts | Swift Charts | The Progress window's week charts. |
| Project file | XcodeGen (`project.yml`) | The Xcode project is generated, so it never has merge conflicts. |
| Tests | Swift Testing | `make test`. |
| Updates | Sparkle 2.10.0 (`AppUpdater`) | The standard for Mac apps outside the App Store. Signed feed (DECISIONS T45). |
| Usage counts | TelemetryDeck ingest API, own sender (`UsageReport`, `UsageCounts`) | Anonymous, with an off switch. Only 6 events and 5 app fields. No SDK (DECISIONS T51). |
| Voice lines | ElevenLabs Eleven v4, made once (`scripts/make-voice.py`) | The app only plays the files. |
| Release | `scripts/release.sh`, `scripts/make-dmg.sh`, `scripts/publish.sh` | See [RELEASE.md](RELEASE.md). |

Minimum macOS: 14 Sonoma. Built with Xcode 26.6 and Swift 6.3 on Hassan's Mac.

## Folders

```
personal-buddy-project/
├── project.yml              Xcode project spec (XcodeGen)
├── Makefile                 make build / test / run / install
├── App/                     The Mac app target (thin: wires the modules together)
│   ├── Sources/
│   │   ├── AxoApp.swift             App entry, menu bar icon, Settings window
│   │   ├── BuddyEngine.swift        The two loops: reminders (5 s) and posture (60 s); sends EngineEvents
│   │   ├── BreakController.swift    Runs one break: notice, island or full screen, end
│   │   ├── EngineLoops.swift        The repeating task for the engine's two loops
│   │   ├── PostureMonitor.swift     Posture state: calibrate, check, nudge streak
│   │   ├── PostureSampling.swift    Runs camera + AirPods, one job at a time (check, calibration, look)
│   │   ├── PresenceWatcher.swift    Starts presence looks after 100 s idle, keeps the result
│   │   ├── ProgressPhotos.swift     Opt-in photos on this Mac: save, list, delete after 30 days
│   │   ├── ProgressTracker.swift    Listener: events into the history, level, form and milestones
│   │   ├── ProgressWindow.swift     The Progress window (from the menu)
│   │   ├── PostureSettingsView.swift  Settings > Posture: sensors, camera, sensitivity, photos
│   │   ├── OnboardingWindow.swift   The setup window (first start, and from the menu)
│   │   ├── OnboardingView.swift     Its pages, Back and Next
│   │   ├── OnboardingPages.swift    Permissions, calibration with countdown, done
│   │   ├── Banners.swift            Notification banners
│   │   ├── VoiceCoach.swift         Listener: plays the voice lines (or a system sound when the voice is off)
│   │   ├── UsageCounts.swift        Listener: anonymous counts to TelemetryDeck (own sender), after setup, with the switch on
│   │   ├── AppUpdater.swift         Sparkle: daily update check, "Check for Updates…", gentle reminder in the menu
│   │   ├── RemindersSettingsView.swift  Settings > Reminders: list, add, reset, break style
│   │   ├── ReminderEditorView.swift     The editor sheet for one reminder
│   │   ├── SettingsStore.swift      User settings, saved on this Mac
│   │   ├── MenuContentView.swift    The menu bar window
│   │   ├── SettingsView.swift       Settings tabs
│   │   └── BuddySettingsView.swift  Settings > Buddy: pick, name, color, menu bar icon
│   └── Resources/               Assets.xcassets (app icon, colors), Voice/*.m4a (53 coach lines)
├── Packages/BuddyKit/       Shared code as a Swift package (tested on its own)
│   ├── Sources/BuddyCore         Pure logic: reminders, schedule, mood, scores, buddy catalog,
│   │                             colors, idle animation. No device code.
│   ├── Sources/PostureEngine     Camera + AirPods readers, calibration, posture rules
│   ├── Sources/ActivityMonitor   Idle time, mic in use, screen locked or asleep
│   ├── Sources/History           The history in SwiftData: checks, reminder records, day totals
│   └── Sources/NotchUI           The notch island window and views, the Progress dashboard, the buddy art
│       └── Resources/Buddies     catalog.json + <buddy id>/<pose>.png (written by scripts/export-buddy-assets.py)
├── design/                  Character options and, later, the final art
└── docs/                    Product spec, decisions, roadmap, privacy, release
```

Rule: **logic goes in BuddyCore and has tests.** Device code (camera, AirPods, CoreAudio) stays thin and passes plain values to BuddyCore.

## How it runs

```
                     ┌────────────────────────── BuddyEngine (main thread) ──────────────────────────┐
 every 5 s           │                                                                                │
 ActivitySensors ───▶│ ActivityState.resolve ─▶ TickTiming ─▶ ReminderSchedule.advanced ─▶ due ──────┼─▶ PromptQueue (island)
 (idle s, mic on?)   │                (gap > 30 s = away)                                             │   + banner + sound
 ScreenStateMonitor ▶│                                                                                │
 (locked / asleep?)  │                                                                                │
 every 60 s          │ PostureCheckPolicy (which sensors may run now?)                                │
 PostureSampling ───▶│ PostureEvaluator.check: one vote per sensor, camera first ─▶ PostureCheck ─────┼─▶ buddy mood, score
 (camera 3 s,        │        ▲                                                      │                │
  AirPods 3 s)       │        └── PostureBaseline.learning (one step, clamped near the calibration) ◀─┘│
                     └────────────────────────────────────────────────────────────────────────────────┘
```

Reminders:

- `ReminderSchedule` is a value type. Each tick returns a new schedule and the reminders that are due. Nothing changes in place.
- `.active` and `.inMeeting` count time. `.inMeeting` holds due reminders until the call ends.
- `.away` counts only wall-clock reminders (water). After 3 more minutes away, sitting reminders start again, and their waiting prompts are taken back from the island.
- A due reminder that waits (in a call, away) does not count. Its next interval starts when it is shown. Done starts it again from that moment.
- The engine measures the real time since the last tick (`ContinuousClock`, which also counts sleep). A gap over 30 s means the Mac slept or the lid was closed, and the whole gap counts as `.away` (`TickTiming`). A lunch with the lid closed is a break.
- A locked screen, a sleeping display, a sleeping Mac or another logged-in user (`ScreenStateMonitor`) counts as `.away`.

Away and in a call:

- In a call = another app records from a real microphone. On macOS 14.2+ the app asks CoreAudio which processes run audio input (`kAudioProcessPropertyIsRunningInput`) and how many input devices each uses. It skips itself, processes with no input device, and "Hey Siri" (`com.apple.CoreSpeech`). The rule is pure: `MicrophoneUse.isInUse`. Before 14.2 it asks every device that has input streams if it is running.

Posture:

- `PostureCheckPolicy` decides which sensors may run. Nothing runs unless the user is `.active` and the screen is unlocked. The camera runs only if the user touched the keyboard or mouse in the last 30 s (`.active` lasts 2 minutes after input, too long for a camera).
- `PostureSampling` runs one sample at a time. A calibration waits for a running check. A check whose sample ended during a calibration is thrown away.
- `PostureEvaluator.check` takes one majority vote per sensor. The camera decides. AirPods decide only when the camera saw nobody (`.unknown`). So 75 AirPods readings cannot outvote 12 camera readings.
- Learning: after a good check, the baseline takes one 5% step toward the mean of the deciding sensor's good readings. It stays within 10% (head height, shoulder width) or 3 degrees (tilt, pitch) of the calibrated baseline, which is saved apart as the anchor. Slow slouching cannot become the new normal. It is saved only when it changed.
- The camera sampler checks before each sample that its camera is still connected. A session error or interruption (`AVCaptureSession.runtimeErrorNotification`, `wasInterruptedNotification`) or a sample with no frames makes it build the input again on the next sample. "No camera" shows in the menu.
- AirPods head motion runs on the sampler's one serial queue (an `OperationQueue` on top of it).
- Camera and AirPods keep separate error messages (`SensorStatus`). Each shows in the menu only while that sensor is on.
- Presence: after 100 s with no input, `PresenceWatcher` asks for a camera look (face or upper body, 3 s at most, ends at the first hit). A person seen keeps the user `.active` for 90 s; the next look is 60 s later. Nobody seen: `.away` until the next input. Rules: `Presence` (BuddyCore). See DECISIONS T27.
- Sensitivity (relaxed, normal, strict) scales the posture limits (`Thresholds.standard(for:)`).
- The camera pick (`CameraChoice`): the saved camera while connected, else built-in, else wired, else iPhone.
- Progress photos (opt-in): a check asks the camera for one JPEG frame only while a photo is due today. `ProgressPhotoPolicy` picks the kind; `ProgressPhotos` saves it owner-only, out of Time Machine, and deletes photos 30 days old.

Settings:

- `SettingsSnapshot` (BuddyCore) is the saved format. A missing field gets its default, a broken field resets only itself, and a reminder with a zero or negative interval is dropped instead of crashing the app.
- Saved under the UserDefaults key `Axo.settings.v1`. The buddy fields: `buddyID` (default `25-axo-axolotl`), `buddyName` (nil = the buddy's own name, at most 16 characters), `buddyColor` (default `original`), `menuBarIcon` (default `outline`), `unlockCodes` (the codes that opened a locked pack).

## Progress

```
 EngineEvent ─▶ ProgressTracker ─▶ historyRecord ─▶ HistoryStore (SwiftData file)
                     │            DayTotals.applying ─▶ ProgressState ─▶ Progression.milestones
                     │                                       │ level, form          │
                     ▼                                       ▼                      ▼
              Progress window                     BuddyAppearance.form      engine.celebrate: moment,
              (ProgressDashboard)                 (island, menu, settings)  "grew up" prompt, .milestone event
```

- `DayTotals` (BuddyCore): one local day. Good checks, known checks (unknown ones do not count), finished breaks, done reminders, seconds at the Mac. The goal (score 70 or more from at least 10 checks) stays reached for the day once reached.
- `ProgressState` and `Progression` (BuddyCore): XP is 1 a good check, 10 a finished break, 25 a goal day. Level L needs 150 × (L − 1)² XP. Forms start at levels 1, 3, 6, 10 and 15; a new buddy is form 1 (baby). Streak: goal days in a row, today counted once reached. Weekly goal: 5 goal days in the calendar week.
- The engine sends `.atMac(seconds:)` each tick while the user is active or in a call. The tracker writes today's totals at most once a minute for it, and at once for every other change. `flush()` writes the rest when the app quits.
- `HistoryStore` is a protocol in BuddyCore. `SwiftDataHistoryStore` (History) is the file store at `~/Library/Application Support/Axo/History.store`, with a `VersionedSchema` and a migration plan. When it cannot open, an `InMemoryHistoryStore` keeps the session and the Progress window says so.
- Checks and reminder records are kept 90 days (`HistoryPolicy`). Day totals stay, so the level never goes back. "Delete history…" in the Progress window deletes all.
- Forms: `BuddyAppearance.form` comes from the level. Art lookup tries `formN-<pose>` first, then the plain pose, so a buddy with no form art (the duo, #39) keeps its normal art.
- `ProgressDashboard` (NotchUI) has plain inputs, so tests draw it off screen (`AXO_SNAPSHOT_DIR`).

## Breaks

```
 reminder due ─▶ BreakStrictness.delivery
                 ├─ gentle ─────────▶ island prompt ─▶ Done ─▶ break in the island (BreakIslandView)
                 └─ skippable/locked ▶ island notice (10 s / 30 s, "Start now", Snooze if skippable)
                                       └─▶ BreakScreens: one panel per screen (BreakScreenView)
 break ends: finished · skipped (End, Skip, Esc) · emergencyExit (hold 3 s) · interrupted (call, lock, sleep)
```

- `BreakSession` (BuddyCore) is a value. `state(at:)` gives the step, pose, text and time left for any moment, so the views only redraw.
- `StretchRoutine` holds 8 routines. Each reminder kind has a default routine; the user can pick another in the editor. Water and custom reminders use a plain timer.
- `BreakController` (App) owns the one running break and the notice timer. A second due break waits as a normal prompt.
- `BreakPanel` is a borderless panel at `.screenSaver` level on every Space, with the same two traps as the notch panel (`constrainFrameRect`, level after `isFloatingPanel`). A key monitor swallows keys while it shows.
- The engine sends `EngineEvent`s (break started and ended, reminder due, posture nudged, calibration) to listeners: `ProgressTracker` (history), `VoiceCoach` (voice) and `UsageCounts` (anonymous counts).
- Buddy moments (`BuddyMoment`): short poses in the island, for example a wave at start and a fist bump after a finished break.

## Voice

```
 EngineEvent ──▶ VoiceScript.line(for:hour:turn:) ──▶ VoiceQueue (≤ 3, ≤ 10 s old) ──▶ VoiceGate ──▶ AVAudioPlayer
 breakStarted ─▶ VoiceScript.breakPlan(for:) ──▶ a timed task adds each move's line at its offset
 breakEnded ───▶ stop the line, the queue and the break task, then say the end line
```

- The words are in `design/voice/lines.tsv`. `scripts/make-voice.py` makes `App/Resources/Voice/<id>.m4a` with ElevenLabs (see `design/voice/README.md`). A test checks that every `VoiceLine` has a file and a row, and that no file is left over.
- `VoiceGate` is checked when a line joins the queue, and again (with a fresh mic check) right before it plays. When the gate is closed, the waiting lines are dropped.
- With the voice off, a reminder or a nudge plays the "Glass" system sound when Sound is on. Settings > General has Sound, Voice coach, a volume slider and a Play button.

## The notch island

- `NotchGeometry` finds the notch from `NSScreen.safeAreaInsets` and the two menu bar areas beside the notch. If there is no notch, it places a fake island at the top center.
- `NotchPanel` is a clear, borderless `NSPanel` at `.mainMenu + 1` level, on all Spaces and over full-screen apps. Two traps, both fixed and commented in the code:
  1. AppKit moves windows below the menu bar. `constrainFrameRect` is overridden to stop that.
  2. `isFloatingPanel = true` resets the level to `.floating` (below the menu bar). Set `level` after it.
- The panel is always the expanded size. Its clear parts let clicks through to the windows below.
- The hosting view returns `acceptsFirstMouse = true`. The panel never becomes key, so without it Done and Snooze need two clicks.
- Prompts wait in a `PromptQueue` (BuddyCore). A new prompt never replaces one on screen. The next one shows after Done, Snooze or auto-close.
- An unanswered prompt closes by itself after 30 s. It keeps waiting at the back of the queue, and the compact island shows a small orange dot. Hover shows it again. Hover opens the island only after the pointer rests on it for 0.4 s. See DECISIONS.md T10.
- The buddy is 26 pt tall in the compact island and 92 pt in the open island. The open island shows the buddy's name above the prompt title.

## The buddy

```
 settings (buddyID, buddyName, buddyColor) ─▶ BuddyAppearance.resolve ─▶ IslandModel.buddy ─▶ BuddySpriteView
                                              (unknown id = Axo)                                 │ mood ─▶ pose
                                                                                                 ▼
 BuddySprites.shared:  BuddyAssets.candidates ─▶ first PNG on disk ─▶ HueSwap on its pixels ─▶ cached NSImage
                       ("form3-calm", "calm", "form3-happy", "happy")   (skipped for `original`)
```

- `BuddyCatalog` (BuddyCore) reads `catalog.json`: id, number, name, main hue, an optional hue window, and the exported art. A broken entry is skipped. An unknown id falls back to Axo.
- `BuddyAssets` maps a mood to a pose (`celebrating` = `celebrate`) and lists the file names to try. Buddies grow through 5 forms with the level (see "Progress"); form 2 is the plain pose set. Fallbacks: `calm` and `blink` use `happy`; `formN-<pose>` uses `<pose>`.
- `HueSwap` (BuddyCore) recolors: pixels within 30 degrees of the main hue (or the buddy's `hueTolerance`) and with saturation 0.12 or more turn to the target hue. Eyes, white, dark outlines and skin stay. It works on premultiplied RGBA bytes, once per distinct color. See DECISIONS.md T16 and T17.
- `BuddySprites` (NotchUI, main thread) lists each buddy's folder once, loads PNGs with ImageIO, recolors, and caches per buddy, color and file (at most 256 images, about 40 MB). Every lookup can return nil; views then show a symbol.
- `BuddySpriteView` draws a pose with a small idle loop: a 1 pt bob in 2 steps, and a blink while calm or happy when the buddy has `blink` art. `BuddyIdleAnimation` (BuddyCore) gives the frame for any time, and a `TimelineSchedule` redraws only when the frame changes. Reduce Motion shows a still frame.
- Locked packs (DECISIONS T54): `BuddySprites.unlock(code)` tries the code on each `Resources/Packs/*.axopack`. `BuddyPack.opened` (BuddyCore) checks the file, decrypts it and checks every id and file name. The pack's buddies join the catalog, and their PNG files stay in memory. A buddy id from the open catalog always wins. The app unlocks the saved codes (`SettingsSnapshot.unlockCodes`) before the engine first reads the catalog. The code field is `UnlockCodeSection` in Settings > Buddy.
- Menu bar icon (`BuddySprites.menuBarImage`, 18 pt): `outline` uses `menubar-outline` as a template image (macOS colors it for light and dark menu bars), or the mood symbol when the art is missing. `color` uses `menubar-color` in the buddy's color, or the happy pose.

## Privacy by design

- Camera frames live only in memory, in the camera queue, and are dropped after the body-pose step.
- The app makes two kinds of network calls, both listed in [PRIVACY.md](PRIVACY.md) rule 8: the Sparkle update check and the TelemetryDeck counts.
- `UsageSignal` (BuddyCore) is the only place that turns an event into a count. Posture, presence, voice and progress events never become counts (a test checks this).
- `UsagePolicy`: a count goes only with an app id, after the setup window, with the switch on. Turning the switch off drops waiting counts and deletes the install id. `UsageReport` is the exact request body, so a test proves which fields leave the Mac.

## Known gaps in the foundation

| Gap | Plan |
|---|---|
| The duo (#39) has no form art and no blink | The code falls back to the plain poses (see "The buddy") |
| Buddies with little color (Bit, Nubo, Hoot, Usa) barely change with a color choice | Inherent to the art. Fix in the art or with a per-buddy `hueTolerance` |
| The buddy menu bar icon does not show "paused" (the old symbol did) | Add a paused look when the art exists |
| Mic detection not yet tested in a real Zoom, Meet or Teams call | Test on hardware before release |
| A new "Hey Siri"-like system listener could count as a call | Add its bundle ID to `MicrophoneUse.ignoredBundleIDs` |
