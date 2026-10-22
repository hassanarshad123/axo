# Axo: rules for coding agents

A free macOS menu bar app. A buddy character lives in the MacBook notch and helps with posture and breaks.
Read `docs/PRODUCT.md` (what) and `docs/ARCHITECTURE.md` (how) before a big change. Log decisions in `docs/DECISIONS.md`.

## Commands

```sh
make test      # swift test for Packages/BuddyKit (fast, no Xcode project needed)
make build     # xcodegen generate + xcodebuild Debug
make run       # build and open the app
make install   # Release build in /Applications (Hassan's daily copy, see docs/DAILY-USE.md)
```

Run `make test` and `make build` before each commit. Both must pass with no warnings.

## Layout

- `Packages/BuddyKit/Sources/BuddyCore`: pure logic (reminders, schedule, mood, scores). No AppKit, no devices. **All logic goes here, with tests.**
- `Packages/BuddyKit/Sources/PostureEngine`: camera (Vision body pose) and AirPods (CoreMotion). Keep device code thin; math goes in pure functions with tests (see `BodyPoseMetrics`).
- `Packages/BuddyKit/Sources/ActivityMonitor`: idle time and mic-in-use. Raw signals only.
- `Packages/BuddyKit/Sources/NotchUI`: the notch window and island views.
- `App/`: the app target. Thin. Wires modules together, holds settings.
- `project.yml` is the source of truth for the Xcode project. Never commit `*.xcodeproj`, `App/Info.plist` or `App/Axo.entitlements` (all generated). Change Info.plist keys and entitlements in `project.yml`.

## Code rules

- Swift 6 strict concurrency. UI and engine state are `@MainActor`. Device readers are `@unchecked Sendable` with one private serial queue; say so in a comment.
- Value types for state. Return a new value, do not change one in place (see `ReminderSchedule.advanced`).
- Tests: Swift Testing (`import Testing`, `@Test`, `#expect`). Write the test first for new logic.
- Files under 400 lines. Functions under 50 lines.
- No new third-party package without a row in `docs/DECISIONS.md`. The code goes MIT at launch, so check the license (no GPL).

## Privacy rules (from docs/PRIVACY.md, do not break)

- Never save or send a camera frame, unless the user turned on progress photos.
- No network call that is not listed in `docs/PRIVACY.md`.
- Never listen to the microphone. Only ask if it is running.

## Notch window traps (already fixed, do not undo)

- `NotchPanel.constrainFrameRect` returns the frame unchanged. Without it, AppKit pushes the island below the menu bar.
- Set `level` after `isFloatingPanel`. That property resets the level to `.floating`, below the menu bar.

## Character art

Made with Codex image generation: `scripts/codex-image.sh <out.png> "<brief>"`. See `docs/CHARACTER.md`.
