# Roadmap

Hassan's choice (2026-10-21): build all features first, then start to use the app.
The milestones below are the build order. Each one ends with tests and a check on a real Mac.

| # | Milestone | Contents | Status |
|---|---|---|---|
| 0 | Foundation | Repo, docs, Swift package, notch island, reminder engine, posture engine, settings, 42 unit tests | ✅ Done 2026-10-21 |
| 1 | Character pick | 15 pixel options made with Codex. Pick: Axo, the pink axolotl. Name: Axo. Users pick from 16 buddies (Hassan added). More buddies open with a code (DECISIONS #54). | ✅ Done 2026-10-21 |
| 2 | Character assets | For each single buddy: 8 core poses, 24 moods and stretches, 5 forms, the core poses for each form, 2 menu bar icons. The duo: 8 core poses and 8 together moments. For Axo: app icon (Notch), 4 onboarding images, DMG background, website hero, social card. In the app: buddy picker, name, color (per-buddy settings), menu bar icon choice, blink and bob. | ✅ Done 2026-10-21. Onboarding screens use the art in milestone 4. |
| 3 | Reminders, complete | Edit text and times, add/delete custom reminders, reminder queue, full-screen break (skip + locked), stretch routines with the buddy | ✅ Done 2026-10-22. Notice before a full-screen break, 3 s emergency exit, 8 routines, buddy moments, "Stretch now" in the menu. |
| 4 | Posture, complete | Onboarding + calibration screen, camera picker, presence detection, tune thresholds on real data, opt-in progress photos | ✅ Built 2026-10-22: setup window, camera picker, presence look, sensitivity, progress photos. Tuning on real data waits for milestone 7. |
| 5 | Progress | SwiftData history, daily score, streaks, weekly charts, levels and buddy growth | ✅ Built 2026-10-22: history on this Mac (90 days of detail), daily and weekly goals, streak, XP, levels, 5 forms, Progress window. A check in the real app waits for milestone 7. |
| 6 | Voice | Write about 50 calm-coach lines, make them with ElevenLabs, play them for nudges and stretch counts | ✅ Built 2026-10-22: 53 lines (Eleven v4, voice "Kristen"). The coach says hello, reminders, nudges, each break move, "3, 2, 1", goals and level-ups. Quiet in calls, while the mic runs and on a locked screen. Separate Sound and Voice switches, with a volume. On by default (#51, Hassan to confirm). |
| 7 | Hassan uses it daily | 1 to 2 weeks of real use. Fix what annoys. | 🟡 `make install` puts a signed Release build in /Applications. What to watch and how to report it: `docs/DAILY-USE.md`. The 1 to 2 weeks of use are Hassan's. |
| 8 | Release setup | Developer ID signing (Zensbot LLC), notarization, DMG, Sparkle auto-update, Homebrew cask, TelemetryDeck counts, privacy notice | ✅ 2026-10-23: Sparkle update check (daily, signed feed, "Check for Updates…" in the menu), anonymous usage counts with an off switch, update key, `release.sh` (sign, notarize, DMG, feed, cask) and `publish.sh`. Version 1.0.0 is signed in the cloud with the Zensbot LLC Developer ID and notarized by Apple (docs/RELEASE.md). |
| 9 | Public launch | Landing page, make the repo public (MIT), launch posts | ✅ 2026-10-23: public repo `hassanarshad123/axo` (MIT code, `ASSETS-LICENSE.md` for the art), GitHub release v1.0.0 with `Axo.dmg`, Homebrew tap, website and privacy notice at axo.zensbot.com. The launch posts are Hassan's to post. |

## Things Hassan must do or approve

- ~~Pick the character (milestone 1).~~ Done: Axo.
- ~~Pick a domain for the download page.~~ Done: axo.zensbot.com.
- ~~Make the Developer ID certificate and the notarization key.~~ Not needed: Xcode signs in the cloud (DECISIONS T56). The TelemetryDeck app id is optional.
- Approve the items in docs/launch/APPROVALS.md (the FAQ lines and the launch posts are still open on 2026-10-22).
