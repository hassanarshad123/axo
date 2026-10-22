# Build plan: milestones 3 to 9

Written 2026-10-22. Hassan's answers (2026-10-22):

| Question | Answer |
|---|---|
| Voice | ElevenLabs, best model and best quality. Credits are not a concern. |
| Download page | `axo.zensbot.com`, hosted free on Cloudflare Pages |
| Signing | Hassan makes the Developer ID certificate and the App Store Connect API key later |
| Publish | Everything (public repo, website, GitHub release, Homebrew, posts), but **only after signing works** |

So: build and test everything now. Stage the release. Publishing is one command (`scripts/publish.sh`) that runs after signing exists.

## Order of work

```
 M3 reminders ─▶ M4 posture ─▶ M5 progress ─▶ M6 voice (app side) ─▶ M8 release setup ─▶ review ─▶ M7 install
      ▲                                           ▲                        ▲
      │ (in parallel, helper agents)              │                        │
      ├── voice lines + audio (ElevenLabs) ───────┘                        │
      └── website + privacy notice + launch posts ─────────────────────────┘
                                                        publish (M9) waits for signing
```

Each milestone ends with `make test`, `make build` (no warnings), the Swift lint and one commit.
All logic goes in BuddyCore with tests written first. Files stay under 400 lines, functions under 50.
`BuddyEngine.swift` is 331 lines now, so new engine work goes into separate files (break, voice, history).

## M3: reminders, complete

BuddyCore (pure, tested):
- `Reminder` gets `routineID: String?` (missing in old settings = the default routine for its kind).
- `ReminderRules`: limits (title 1 to 40 characters, message up to 140, interval 1 to 240 min, break 0 to 15 min), and list changes as new values: add, update, delete (custom reminders only), reset built-ins to defaults.
- `StretchRoutine`: an id, a title and steps (pose, instruction, seconds, voice line id). Routines: neck, shoulders, back, wrists, eyes, stand and move, breathe. Poses come from the stretch sheets: neck-left, neck-right, chin-tuck, shrug, chest-open, twist-left, twist-right, wrist, reach, side-bend, march, walk, breathe, palming, sit-tall.
- `BreakSession`: built from a reminder and the break style. It gives the state at any time: current step, seconds left, finished. Locked breaks have an emergency exit (hold Esc for 3 s), so nobody is ever trapped.
- `BuddyMoment`: hello (wave), walk break (walk), focus (laptop), chai break (chai), good job (thumbs-up), break done (fist-bump), breathe (breathe), weekly goal (trophy). These are the duo's moments (DECISIONS #39). Every buddy uses the same names.
- `BuddyAssets` fallbacks for poses a buddy lacks: chai to water, fist-bump and trophy to celebrate, laptop and thumbs-up and wave to happy, walk and march to stretching, neck poses to neck, other stretch poses to stretching, breathe and palming to calm then happy.

App and NotchUI:
- Break style "gentle": after Done, the island shows the routine: the pose, the step text and a countdown, with an End button.
- Break styles "full screen with Skip" and "full screen, locked": a window on every screen, above all apps, with the buddy doing each step, a countdown ring and Skip (when allowed).
- Settings > Reminders: an editor for each reminder (title, message, every N min, break length, counts while at the Mac or real time, routine, on/off), delete for custom ones, and "Reset built-in reminders".
- Moments in use: hello at app start, good job when posture is fixed after a nudge, break done after a finished break, weekly goal (M5).

## M4: posture, complete

- First-start window: welcome, pick a buddy, privacy, permissions (notifications, camera), calibration with a live "I can see you" check and a 5 s countdown, AirPods (optional), done. Uses the Axo onboarding art. Shown once (`hasFinishedOnboarding`), and again from the menu.
- Camera picker in Settings > General (built-in, external, iPhone Continuity Camera). Saved by device id. A missing camera falls back to the default one.
- Presence: when there is no input for 2 min and the camera is on, a 1 s camera check looks for a person. A person seen = still active (reading). The next check runs a minute later. When a check sees nobody, the user is away and the checks stop until the next input. Pure rule: `PresencePolicy`. New decision row, it changes T13.
- Sensitivity setting (relaxed, normal, strict) that scales the posture limits. Real tuning comes from Hassan's daily use (M7) with the history from M5.
- Progress photos (opt-in, off by default): one a day and at most one bad-posture photo a day. Saved only in `~/Library/Application Support/Axo/Photos`. Deleted after 30 days. "Delete all photos" button. Pure rules: `ProgressPhotoPolicy`.

## M5: progress

- New package module `History` with SwiftData (macOS 14). A `HistoryStore` protocol in BuddyCore keeps the logic free of storage. Tests use an in-memory store.
- Saved: each posture check (time, result, issues, sensor), each reminder event (shown, done, snoozed, skipped, break finished), minutes at the Mac per day.
- BuddyCore: `DaySummary`, daily score (good checks / all checks, 0 to 100), streak (days in a row at or above the goal, default 70, with at least 10 checks), weekly totals, XP and levels.
- Levels and forms: XP from good checks, finished breaks and goal days. Form 1 (baby) at the start, then forms 2 to 5 at set levels. A level up shows the celebrate pose and a "grew up" prompt. Buddies without form art (the duo) keep their normal art.
- Progress window (Swift Charts): today (score, checks, breaks, time at the Mac), this week (3 charts), the buddy (level, XP bar, the 5 forms with locked ones dark), photos (when on).

## M6: voice

- About 52 lines in a calm-coach voice: posture nudges, each reminder kind, break start and end, each stretch step, counts, welcome and calibration, level up, streak, weekly goal.
- Line ids live in BuddyCore (`VoiceLine`), the text in `design/voice/lines.tsv`.
- `scripts/make-voice.py`: ElevenLabs, best model, best output quality, one calm voice. Saves `App/Resources/Voice/<id>.m4a`. The key comes from `~/.secrets` and is never printed.
- `VoiceCoach` in the app: plays one line at a time, never in a call, never on a locked screen, only when Voice is on. Settings get separate Sound and Voice switches and a volume.

## M8: release setup

- Sparkle 2 (MIT) for updates. Feed: `https://axo.zensbot.com/appcast.xml`. EdDSA private key in `~/.secrets`, public key in Info.plist. "Check for updates" in the menu. No system profile is sent.
- TelemetryDeck (MIT) for anonymous counts. Off when no app id is set. Settings switch "Share anonymous usage counts" (on by default, PRIVACY.md rule 7). Signals: app start, reminder done or snoozed (kind only), break finished, onboarding finished, buddy picked.
- `scripts/release.sh <version>`: archive, sign with Developer ID, notarize, staple, DMG with the Axo background, sign and notarize the DMG, Sparkle appcast. Stops with a clear message while the certificate or the API key is missing.
- `scripts/publish.sh <version>`: secret scan, MIT license, public repo, GitHub release, Homebrew tap (`hassanarshad123/homebrew-axo`), website deploy, check the live URLs.
- Version 1.0.0. `docs/RELEASE.md` lists the exact steps Hassan must do on developer.apple.com.

## M9: public launch (staged, not published)

- `site/`: home page (hero art, features, the 16 open buddies, privacy summary, download and Homebrew), privacy notice, appcast. Static files for Cloudflare Pages.
- Privacy notice: the public text. It lists every network call and every piece of data.
- `docs/launch/`: posts for LinkedIn, X, Reddit (r/macapps), Show HN and Product Hunt.
- Before the repo goes public: secret scan of the whole history, and a check that no real-person photo is in it.

## M7: Hassan uses it daily

- Release build installed in `/Applications`, open at login on.
- `docs/DAILY-USE.md`: what to watch and how to report it. The 1 to 2 weeks of use are Hassan's.

## Fixes from the plan review (2026-10-22)

An Opus reviewer read this plan and the code. These changes are now part of the plan.

| # | Area | Change |
|---|---|---|
| 1 | Forms | Forms 1, 3, 4, 5 have only the 8 core poses. Stretch and moment poses use the exact pose first (any form), then the fallbacks. Calm and blink keep "same form first". |
| 2 | Locked break | One non-activating panel per screen that can take keys, level above all apps, on all Spaces. No `presentationOptions`. Esc held 3 s **or** the mouse held 3 s on "Hold to leave" ends it. A lock, sleep or call ends it. The notice before a locked break is 30 s (10 s when it can be skipped). Panels are made again when screens change. |
| 3 | Engine size | `EngineEvent` in BuddyCore. Break, history, voice and counts listen to events, so `BuddyEngine` stays small. |
| 4 | Presence | Check at about 100 s idle (before "away" at 120 s). Look for a face or a person shape, not the full body pose. Sample until the first hit, 3 s at most. Update T13, PRIVACY rule 2, the camera text and the public notice. |
| 5 | Install | Sign local and M7 builds with the "Apple Development" identity, so the camera permission stays after a rebuild. |
| 6 | Release | Raise `CFBundleVersion` each release. Staple before the EdDSA signature and the cask checksum. Export with method `developer-id`. Check with `codesign --deep --strict` and `spctl`. |
| 7 | Links | Make the appcast and the cask only after the repo is public. Check each URL with an anonymous `curl -I`. The DMG stays on GitHub (Pages limit: 25 MiB). Run `brew audit --strict`. |
| 8 | SwiftData | Store file in `~/Library/Application Support/Axo/`. `VersionedSchema` V1. Main actor, plain fields. Logic tested with an array fake. |
| 9 | Counts | TelemetryDeck starts only after onboarding, only with the switch on. No automatic session signals. The notice lists the default fields. |
| 10 | Photos | Copy a frame only when photos are on. Exclude the folder from Time Machine. Strip metadata. New camera text. |
| 11 | Voice | Voice folder added as a folder in `project.yml`. Audio converted with `afconvert`. One voice in v1 (new decision row). |
| 12 | Gaps | Posture nudges also send a banner. |
| 13 | Hassan | His list below gets: confirm the Apple team, approve the notice, pick the art license, post on Reddit, HN and Product Hunt himself. |
| 14 | macOS 14 | The app targets macOS 14 but this Mac runs a newer one. A macOS 14 test in a free virtual machine is listed for Hassan. |
| 15 | Camera picker | Use the `.external` and `.continuityCamera` device types. Add the Continuity Camera key. Rebuild the session when the pick changes. Default: the built-in camera. |

Defaults I picked so the work does not stop (Hassan can change each one):

| Question | Default | Why |
|---|---|---|
| First form of a new buddy | Form 1 (baby) | DECISIONS #32: "It should grow up like Pokemon". |
| License | MIT for the code. Art, voice and the real-person buddies: all rights reserved. | MIT on the art would let anyone reuse a real person's likeness. Approved 2026-10-22 (DECISIONS #52). |
| Voices | One calm voice in v1 | More voices can come later. DECISIONS #35 said "voice comes later". |

## What Hassan must do

1. Confirm that Apple team 5PDR77PRWF is Zensbot LLC and that you are its Account Holder. Only the Account Holder can make a Developer ID certificate.
2. Make the "Developer ID Application" certificate and an App Store Connect API key (steps in `docs/RELEASE.md`). The APNs key in `~/.secrets` cannot notarize.
3. Optional: make a free TelemetryDeck app and give me its app id. Without it, no counts are sent.
4. Read and approve the public privacy notice, and pick the license for the art.
5. Use the app for 1 to 2 weeks and tell me what annoys.
6. Post on Reddit, Hacker News and Product Hunt yourself. Those sites ban posts from bots.
