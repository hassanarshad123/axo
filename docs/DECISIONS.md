# Decision log

Each row is one decision. Date format: YYYY-MM-DD. Add new rows at the bottom. Do not edit old rows: add a new row that replaces them.

## 2026-10-21: first interview with Hassan

| # | Question | Decision | Why / note |
|---|---|---|---|
| 1 | Tech stack | Native Swift + SwiftUI | Small app, low battery use, best camera and privacy tools. Mac only. |
| 2 | How to check posture | Camera + AirPods | AirPods are the backup when the camera is off. |
| 3 | Camera pictures | Save a few snapshots locally | Refined by #11: opt-in only. |
| 4 | Bad-posture alert | Menu bar icon, notification banner, sound or voice, buddy in the notch | Hassan: "a buddy that lives on my screen, like the island on MacBooks and iPhones". |
| 5 | Buddy look | Cute animated character | Hassan: "This is really important. This is about branding our character." Make 10 to 15 options with Codex. Hassan picks one. Then make all assets with Codex. |
| 6 | Mac with no notch | Fake island at top center | One design on every screen. |
| 7 | Reminders | Stand up, stretch, eye rest (20-20-20), water | Hassan: fully customizable, each person sets their own. |
| 8 | Break strictness | User picks, default gentle | |
| 9 | Camera mode | Short checks each minute | Low battery. The camera light blinks. |
| 10 | Calibration | Calibrate once, then learn over time | |
| 11 | Snapshots | Off by default, user opts in. 1 per day + 1 on bad posture, deleted after 30 days | |
| 12 | Auto pause | When away from the Mac, during calls | Not chosen: full-screen video, Focus mode. |
| 13 | Tone of voice | Calm coach | |
| 14 | Voice | Pre-made ElevenLabs voice lines in the app | About 50 lines. Small one-time cost. |
| 15 | Progress | Daily score, streaks, weekly charts, buddy levels up | |
| 16 | Language | English only, ready for more | |
| 17 | Download | Website `.dmg` + Homebrew | Needs the $99/year Apple Developer Program. |
| 18 | Apple account | Zensbot LLC account | |
| 19 | Open source | Private now, MIT at launch | |
| 20 | Money | Free forever, branded Hassan Arshad | |
| 21 | Maker name | OK that the install screen says "Zensbot LLC" | Brand and About page say Hassan Arshad. |
| 22 | App name | Decide after the character | Working name: Personal Buddy. |
| 23 | macOS versions | 14 Sonoma and newer | First version with AirPods head motion on Mac. |
| 24 | Usage data | Anonymous usage counts | Needs a privacy notice before launch. |
| 25 | Art styles for options | All four: soft 3D, flat vector, pixel art, kawaii | |
| 26 | Creatures for options | Blob / cloud / bean, animal, small robot | |
| 27 | Stretch teaching | The buddy does the stretch | One art set does two jobs. |
| 28 | First build | Everything, then use it | Claude recommended "notch + reminders first". Hassan chose to build all features first. |

## 2026-10-21: technical choices made by Claude (no product impact)

| # | Decision | Why |
|---|---|---|
| T1 | XcodeGen (`project.yml`) makes the Xcode project. The `.xcodeproj` is not committed. | No merge conflicts in project files. Already installed on Hassan's Mac. |
| T2 | Shared code in a local Swift package, `Packages/BuddyKit`, with 4 modules | Logic is tested with `swift test`, without the app. |
| T3 | Own notch window code, not a third-party notch library | Full control of the character animation, and no license issue for the MIT release. |
| T4 | Swift Testing (`import Testing`) for unit tests | Apple's current test framework. |
| T5 | Not sandboxed. Hardened runtime + camera entitlement. | Direct download does not need the sandbox. Notarization needs the hardened runtime. |
| T6 | Bundle ID `com.hassanarshad.personalbuddy` | Matches the brand. Can change before the first public release. |
| T7 | Settings in `UserDefaults` as JSON for now | Small and simple. History and stats move to SwiftData in milestone 5. |
| T8 | "Away" = 2 min with no input. Sitting timers reset after 5 min away in total. | Known gap: reading without touching the mouse counts as away. Fix later with camera presence. |
| T9 | Meeting = any app uses the default microphone | Covers Zoom, Meet, Teams and FaceTime. Needs no mic permission. Camera-in-use is a later addition. |

## 2026-10-21: fixes after the first code review (technical, made by Claude)

| # | Decision | Why |
|---|---|---|
| T10 | An unanswered island prompt closes by itself after 30 s. It keeps waiting; the compact island shows a small dot, and hover shows it again. Hover opens the island only after 0.4 s. | An open island covers the menu bar and the browser tabs below it. A prompt the user did not see is not lost. The hover delay stops the island from opening when the pointer just passes over it. |
| T11 | Replaces T9. Meeting = another app records from a real microphone, read per app from CoreAudio (macOS 14.2+). Skip our own app, apps with no input device, and "Hey Siri" (`com.apple.CoreSpeech`). Before 14.2: any device with a microphone that is running. | T9 missed calls on a mic that is not the default one. On Hassan's Mac, `corespeechd` reports input all the time with no device, so a plain "any app records" rule would always say "in a call". Still needs no mic permission. |
| T12 | The posture baseline learns once per check (5% toward the mean of the good readings) and stays within 10% (3 degrees for angles) of the last calibration, saved apart as the anchor. | Before, every reading was a step, so 75 AirPods readings moved it far, and slow slouching could become the new "good". |
| T13 | A gap of more than 30 s between two reminder ticks counts as away. A locked screen or a sleeping display counts as away. The camera runs only within 30 s of the last keyboard or mouse input. | A closed lid is a break, not 1 hour of sitting. No camera use when nobody is at the Mac. |
| T14 | The camera decides a posture check. AirPods decide only when the camera saw nobody. | The camera sees the whole upper body; AirPods see only head pitch. Many AirPods readings must not outvote it. |

## 2026-10-21: Axo rename and buddy picker (technical, made by Claude)

| # | Decision | Why |
|---|---|---|
| T15 | Replaces T6. Bundle ID `com.hassanarshad.axo`. Settings key `Axo.settings.v1`. Settings saved under `PersonalBuddy.settings.v1` are not moved. | The app is called Axo now. Only development builds ever saved the old key. |
| T16 | A color choice turns only pixels within 30 degrees of the buddy's main hue with saturation 0.12 or more (`HueSwap`). A buddy can set its own `hueTolerance` in `catalog.json`. | The brief said about 40 degrees. One buddy's skin (hue 15 to 20) is 30 to 35 degrees from its main hue (345), so at 40 the skin turns blue. Eyes, white and outlines have low saturation and stay. |
| T17 | Recoloring runs on the CPU, once per distinct color of the sprite, with the exact `HueSwap` math. Not a Core Image color cube. | Tried first, as briefed. The cube blends between its table points, so colors at the edge of the hue window came out half-turned: about 10% of Axo's visible pixels were off by more than 4%. A sprite has about 130 colors, so the exact way is fast too. Results are cached per buddy, color and pose. |
| T18 | Buddy art ships in the NotchUI package as a resource folder (`Resources/Buddies`: `catalog.json` and `<id>/<pose>.png`). The app reads the folder to see which files exist. Missing art falls back: calm and blink to happy, `formN-<pose>` to `<pose>`, the outline menu bar icon to a symbol, the color one to the happy pose. Only ids from the catalog are read. | The export script adds art over time, so the code must work with any file missing. A saved id cannot point at another folder. |
| T19 | The idle loop (1 pt bob, blink) is a pure function of time (`BuddyIdleAnimation`). The view redraws only when the frame changes, about once every 0.8 s. With Reduce Motion it stands still. Sprites scale smoothly, not pixel by pixel. | No 60 fps timer in the notch. The exported art has soft alpha edges, so nearest-pixel scaling looks rough. |

## 2026-10-21: character pick and buddy options (Hassan)

| # | Question | Decision | Why / note |
|---|---|---|---|
| 29 | Art style | Pixel art. 15 pixel characters with 8 poses each were made as options. | Hassan: "can we have more in pixel arts?" |
| 30 | Brand character | 25 Axo, the pink axolotl | Hassan: "25 axo". |
| 31 | App name | Axo | Replaces #22. |
| 32 | Levels | The buddy grows through 5 forms: baby, normal, evolved, champion, legend | Hassan: "It should grow up like Pokemon". Our own art and words, no Pokémon names or designs. |
| 33 | Menu bar icon | The user picks: a one-color outline or the color head | Hassan: "This should be an option so we can select whatever we like." |
| 34 | Buddy choice | Every user picks a buddy: the 15 pixel buddies and Hassan (#38). Since 2026-10-22, #36 and #39 are in a locked pack (T54). Axo is the default. | Hassan: "they can select their own buddy". |
| 35 | Customize | Name, color and voice. Voice comes later. | Voice uses ElevenLabs credits, so ask Hassan before spending. See #14. |
| 36 | Buddy 28 | A buddy based on a real person, in locked pack 1 since 2026-10-22 (T54). | The person agreed. No photo was sent to Codex. The details are in Hassan's private notes, not in this repo. |
| 37 | App icon | "Notch": Axo peeks out under a black MacBook notch, on lavender | Hassan picked it. Claude recommended "Navy night" for contrast at small sizes. Options and the 1024 px master: `design/axo/`. |
| 38 | Hassan | Buddy 29: Hassan himself, a nerdy desi young man with a heavy black fringe and clear glasses with gold arms. The color option turns his jeans. | Hassan: "this is me hassan". The first version (text only) was wrong: "he is a nerd guy, also he dont have curly hair... clean shave". At his request ("ask codex plugin for it") his photo went to Codex as the reference for his pose sheet. He picked option C. All his other sheets use that pose sheet, not the photo. |
| 39 | The duo | Buddy 30: two buddies together, in locked pack 1 since 2026-10-22 (T54). 8 core poses together, and 8 together moments: wave, walk, laptop, chai, thumbs-up, fist bump, breathe, trophy. | Hassan asked for it. Made from two pose sheets, no photo. Friendly actions only. |
| 40 | Color option | Each buddy has its own color window: center hue, width, and lower limits for saturation and brightness, with soft edges. Settings: `design/buddies/buddy-settings.json`. A color within 25° of the buddy's own color is not offered. | One fixed window turned Neko's mouth and Hammy's blush, left single turned pixels on Shelly, and turned almost nothing on Nubo. Check a change with `scripts/color-sheet.py`. |
| 41 | Art export | Each pixel is solid or see-through (no half alpha), 128 colors. The sheet cut keeps dark pixels from brightness 5 up, and keeps each whole shape in one sprite. | The old export made bodies slightly see-through. The old cut (brightness 28) ate dark hair and outlines, and sliced tails that crossed a cell line. |
| 42 | Blink | The buddy blinks only when calm. The sprite box has a fixed width. | The blink art is the calm pose with closed eyes: in other moods a blink swapped the whole pose. Poses have different widths, so the text next to the buddy moved. |
| 43 | Buddy names | Each buddy keeps its own name, like a nickname. Rename Axo to "Bubbles", switch to Neko: it shows "Neko". Switch back: "Bubbles". A name saved by an older build goes to the buddy picked then. | Hassan picked this over "one name for all" (the old way) and "reset on switch". |

## 2026-10-22: build plan answers (Hassan)

| # | Question | Decision | Why / note |
|---|---|---|---|
| 44 | Voice | Use the best ElevenLabs model and voice. Made with Eleven v4, voice "Kristen - Calm, Comforting, Meditative" (`KGZeK6FsnWQdrkDHnDNA`). 53 lines, 3,032 characters. | Hassan: "Use the best model of Eleven Labs, best everything, because we have a lot of credits". Replaces the cost note in #14 and #35. Script: `scripts/make-voice.py`. |
| 45 | Domain | axo.zensbot.com | Hassan picked the recommended option. |
| 46 | Signing | Build everything now. Make the Developer ID certificate and the App Store Connect key later. | Hassan picked the recommended option. Until then the app is signed with the Apple Development identity and runs on Hassan's Mac only. |
| 47 | Publish | Publish all: public repo (MIT), website, GitHub release, Homebrew cask, launch posts. Only after signing works. | Hassan: "Publish all". Art, voice and the real-person buddies stay "all rights reserved" (see #48). |
| 48 | Licenses (Claude's default, Hassan to confirm) | Code: MIT. Art, voice files and the buddies that show real people: all rights reserved. | Others may copy the code, not the brand or real people. Ask Hassan before the repo goes public. |
| 49 | First form (Claude's default, Hassan to confirm) | A new user starts with the buddy's form 1 (baby). It grows with levels. | Fits "It should grow up like Pokemon" (#32). |
| 50 | Voices in v1 (Claude's default) | One voice for all buddies. | 53 lines × 16 buddies is a lot of audio for little gain. Per-buddy voices can come later. |
| 51 | Voice coach default (Claude's default, Hassan to confirm) | On for every user, at 70% volume. The last page of the setup window and Settings > General turn it off. | A coach that starts off is rarely heard. It stays quiet in calls, while paused and on a locked screen. |

## 2026-10-22: milestone 3, reminders and breaks (technical, made by Claude)

| # | Decision | Why |
|---|---|---|
| T20 | Full-screen breaks start with a notice in the island: 10 s for "skippable", 30 s for "locked". The notice has "Start now", and Snooze when skippable. Then a panel covers every screen. | A break that jumps in with no warning breaks a sentence or a call. 30 s gives time to save work before a break that cannot be skipped. |
| T21 | A locked break has an emergency exit: hold Esc or the "Hold to leave" button for 3 s. A call, a locked screen or sleep ends a full-screen break. | No app may trap a user. 3 s stops a reflex press. Logged as `emergencyExit` so history can tell it apart from a skip. |
| T22 | The engine sends events (`EngineEvent`) to listeners. Sound, voice and history listen. They are not inside the engine. | Keeps `BuddyEngine` under 400 lines. Each listener can be tested alone. |
| T23 | Stretch routines are data (`StretchRoutine`). A break runs the routine's steps, repeats them to fill the break, and joins a last part under 5 s to the step before it. | A 2-minute break and a 90 s routine both work. No 2-second step. |
| T24 | Action poses (stretches, moments) try the exact pose first, in any form. Idle poses (calm, blink) keep the current form first. | A form-3 buddy must show the stretch, not its form-3 happy pose. |
| T25 | Reminder edits go through `ReminderRules.cleaned`: title 40 characters, message 140, interval 1 to 240 min, break 0 to 15 min, at most 20 reminders. Built-in reminders cannot be deleted, only turned off or reset. | One place for limits, with tests. Reset keeps the ids, so progress stays. |
| T26 | Break views are rendered off screen in tests (`ImageRenderer`). `AXO_SNAPSHOT_DIR` saves them as PNG files. | Checks the layout without taking over the screen. The system progress bar does not draw off screen, so the island uses a SwiftUI bar. |

## 2026-10-22: milestone 4, posture complete (technical, made by Claude)

| # | Decision | Why |
|---|---|---|
| T27 | Changes T13 and T8. After 100 s with no input, the camera looks for a face or an upper body (Vision face and human rectangles) for at most 3 s. Seen: the user still counts as active (reading) for 90 s, and the next look is 60 s later. Nobody: away, and no looks until the next input. Rules in `Presence`. | Reading or watching without input counted as away and reset the sitting timers. The look ends at the first hit, so the camera light is on for under a second most times. |
| T28 | Presence looks run only with the camera on, calibrated and already allowed, and never in a call, a break, a pause or on a locked screen. A look that fails counts as "nobody". | Privacy rule 2. A failed camera must not keep the light blinking. |
| T29 | Camera picker: built-in, USB or display cameras and an iPhone (Continuity Camera). The saved pick is used while connected. Otherwise the built-in camera, then a wired one, then the iPhone. Rules in `CameraChoice`. | An iPhone may sit in a pocket, so it is never the automatic pick. |
| T30 | Sensitivity scales all four posture limits: relaxed ×1.4, normal ×1, strict ×0.7. The confidence limit does not change. | One simple setting. Real tuning comes from daily use (M7). |
| T31 | Progress photos: the sample keeps one JPEG frame (mirrored, no metadata) only when the switch is on and a photo is still due today. Bad posture fills the "posture" photo first, good posture the "daily" one. The camera's own vote decides. Files are owner-only (0600 in a 0700 folder) and the folder is left out of Time Machine. | Privacy rule 3. The vote of the camera matches what the photo shows. |
| T32 | A setup window shows at the first start (and from the menu): welcome, buddy, privacy, permissions, AirPods, calibrate with an "I can see you" check and a 5 s countdown, done. Notifications are asked there, not at launch. | People allow a permission more often when they know why. |

## 2026-10-22: milestone 6, voice in the app (technical, made by Claude)

| # | Decision | Why |
|---|---|---|
| T40 | `VoiceScript` (BuddyCore) picks the line for each event. A `turn` number rotates lines with the same meaning. Hello by hour: 4 to 12 morning, 12 to 17 afternoon, else evening. "Welcome back" only after 15 minutes away. A nudge names the first posture problem. A break cut short by a call or a lock gets no line. | Pure rules with tests. 15 minutes: a coffee or a meal, not every short pause. |
| T41 | Break lines: "your break starts now" for breaks of 60 s or more and for plain timers. Each move's line at its start. "Halfway" on timers of 60 s or more. "3, 2, 1" 3 s before the end, but only when the last line started 8 s or more before the end. Recorded but not used in v1: `count-hold`, `count-other-side`, `count-relax`. | A 20 s eye break says only the move. No line talks over another. |
| T42 | `VoiceQueue`: one line at a time, at most 3 waiting (a new line pushes out the oldest), a line that waited more than 10 s is dropped. A break end stops the voice and the waiting lines. | The coach must not talk over itself or say old news. |
| T43 | `VoiceGate`: quiet in a call, while paused, on a locked or sleeping screen, and while any app uses the mic. The mic is asked again right before each line. Away is fine (nobody types on a walk break). | A voice in a meeting is the worst failure. The app still never listens to the mic. |
| T44 | Sound and voice are two switches, plus a volume slider with a Play button. With the voice off, a reminder or a nudge plays the "Glass" system sound when Sound is on. `SoundCues` is removed; `VoiceCoach` (App, `AVAudioPlayer`) replaces it. The 53 `.m4a` files sit at the top of the app bundle. | One listener owns all audio, so a sound and a line never play together. |

## 2026-10-22: milestone 5, progress (technical, made by Claude)

| # | Decision | Why |
|---|---|---|
| T33 | XP: 1 a good check, 10 a finished break, 25 a goal day. Level L needs 150 × (L − 1)² XP. Forms start at levels 1, 3, 6, 10 and 15 (#49: a new buddy is form 1). Rules in `Progression`. | A good 6-hour day is about 300 XP. Form 2 comes on day 2, form 3 on day 13, form 4 on day 41, form 5 after about 100 days. Early growth hooks the user; the last form is a real goal. |
| T34 | The daily goal is a score of 70 or more from at least 10 known checks, and stays reached for the day. The streak counts from yesterday until today's goal is reached. The weekly goal is 5 goal days in the calendar week. | 2 lucky checks are not a goal day. A streak must not drop to 0 each morning. |
| T35 | History in SwiftData (`History` module), `VersionedSchema` V1 with a migration plan, CloudKit off, file at `~/Library/Application Support/Axo/History.store`. If the file cannot open, the session uses memory and the Progress window says so. The logic sees only the `HistoryStore` protocol. | Apple's store, no package to add. A versioned schema from day one makes later changes safe. Privacy rule 4. |
| T36 | Each check and reminder event is kept 90 days. Day totals are kept, so the level never goes back. "Delete history…" deletes all. Only results are saved, never a picture or a measurement. | Enough detail to tune posture limits in M7, small on disk. |
| T37 | Time at the Mac comes from the 5 s tick while active or in a call, and is written at most once a minute. Every other change is written at once. The rest is written when the app quits. | A disk write every 5 s is waste. A crash loses at most 1 minute of time. |
| T38 | The menu's "Posture today" reads the saved history. `DailyChecks` is removed (`DayTotals` replaces it). | The score no longer resets when the app restarts. |
| T39 | A goal, a streak or a new level plays the `celebrate` moment. The weekly goal plays the trophy. A new form also shows a "grew up" prompt. Each sends a `.milestone` event for the voice coach. | One clear reward per step. The prompt asks for one tap, only for the big step. |

## 2026-10-22: milestone 8, release setup (technical, made by Claude)

| # | Decision | Why |
|---|---|---|
| T45 | Updates with Sparkle 2.10.0 (published 2026-09-13), pinned with `exactVersion`. License: MIT, with BSD (bsdiff), MIT (sais-lite) and zlib (ed25519) parts. No GPL. Feed `https://axo.zensbot.com/appcast.xml`, EdDSA public key in `project.yml`, a daily check that the user can turn off, no system profile. | The standard update tool for Mac apps outside the App Store. Signed updates: a hacked web host cannot push a fake app. |
| T46 | **Replaced by T51.** Usage counts with TelemetryDeck SwiftSDK 2.14.2 (published 2026-08-01), pinned with `exactVersion`. License: MIT. `sendNewSessionBeganSignal` and `sessionStatsEnabled` are off. Only the 6 events in `UsageSignal`. Starts at the first allowed count, after the setup window. The switch stops it at once. | A privacy-first count service from the EU. With session stats off, it sends only the events we list. |
| T47 | The Sparkle private key: login Keychain (account "axo") plus `~/.secrets/pem/sparkle-axo-eddsa.key`. It has no copy off this Mac yet. | If the key is lost, no old copy of Axo can update again. An off-Mac backup is a release step (`docs/RELEASE.md`). |
| T48 | A menu bar app has no Dock icon. Near launch, Sparkle shows its update window. Later in the day, the menu shows "Install version …" instead (Sparkle's gentle reminders). | A window that jumps up in the middle of work is the kind of nag Axo must not be. |
| T49 | The usage-count switch is on the setup window's privacy page and in Settings > General. | The user sees the choice before any count goes. |
| T50 | `scripts/release.sh` makes the whole release on this Mac: Release build, Developer ID signature, notarization, DMG, appcast, cask. It stops with a clear message when a key is missing. The build number is the git commit count. | One command, the same steps each time. GitHub Actions cannot run on private repos here (billing). |

## 2026-10-22: fixes after the code review (technical, made by Claude)

| # | Decision | Why |
|---|---|---|
| T51 | Axo sends usage counts itself to TelemetryDeck's ingest API (`POST https://nom.telemetrydeck.com/v2/`). No SDK. `UsageReport` (BuddyCore, tested) is the exact body: the event, its kind or buddy id, app version and build, macOS major.minor, chip type, a test flag, a launch id and the SHA-256 hash of a random install id. Waiting counts stay in memory (50 at most). Turning the switch off deletes the install id. | The SDK added about 60 fields to each count, among them usage history (days used, session count and length, first-use date), screen, locale and accessibility settings. It also kept a session log and shared a queue file in `~/Library/Caches` with every other unsandboxed app that uses it. Now a test proves what leaves the Mac, and there is one third-party package less. |
| T52 | A break notice stops when the user pauses. When a notice runs out while the buddy is paused, in a call or locked, the full-screen break does not start, and the reminder comes back after 5 minutes of counted use. The rule is `BreakSession.mayShowFullScreen`. A notice has its own prompt id (`notice-<reminder id>`). | A full-screen break must never cover a paused buddy or a call. With the shared id, a waiting prompt for the same reminder hid the notice, and the break came with no warning. |
| T53 | A break whose timer runs out more than 5 s after its planned end ends as "interrupted", not "finished". | The timer counts while the Mac sleeps. A Mac that slept through a break must not earn XP or a "break finished" count. |

## 2026-10-22: approvals before publish (Hassan)

| # | Question | Decision | Why / note |
|---|---|---|---|
| 52 | Licenses and defaults | Approved: #48 (code MIT, art, voice, name and real-person buddies all rights reserved), #49 (form 1 first), #50 (one voice), #51 (voice coach on at 70%). | Hassan ticked "Licenses + 3 defaults". |
| 53 | Privacy notice and counts | Approved: the text of `docs/PRIVACY-NOTICE.md` and `site/privacy.html`, and usage counts on by default with an off switch. | Hassan ticked "Privacy notice + counts on". |
| 54 | Secret buddies | Some buddies are locked. A code typed in Settings > Buddy opens them. Hassan gives the code only to the people he picks. Buddies 28 and 30 are in pack 1. | Hassan: "I want to create a code system where I can input a code to access more characters." |
| 55 | Publish date | Today, 2026-10-22, not after a day of use. | Hassan picked "Today". |

## 2026-10-22: locked packs and release (technical, made by Claude)

| # | Decision | Why |
|---|---|---|
| T54 | A locked pack is one file in the app, `Resources/Packs/<name>.axopack`: the text "AXOPACK1", a random 16-byte salt, then AES-GCM (CryptoKit) of a binary plist with the buddies and their PNG files. The key comes from the code with HKDF-SHA256 and the salt. A code is 16 characters from Crockford base32 (80 bits), shown as `XXXX-XXXX-XXXX-XXXX`. O reads as 0, I and L as 1. The art opens only in memory. The saved settings keep the codes that worked, so the pack opens again at each start. `axo-pack` (a command in BuddyKit, not in the app) makes codes and packs. `make packs` locks each folder in `private/packs/` with its code from `~/.secrets` (component `axo`). | Nothing goes over the network, so there is no server and no new privacy item. A wrong code cannot read the names or the art. 80 bits cannot be guessed. A pack cannot point at another folder: ids and file names are checked. Old rows #34, #36, #39, T16 and #48 were made neutral on this day so the public repo names no private person. |
| T55 | The public repo `hassanarshad123/axo` is a fresh copy of the release commit, with one commit per release. It leaves out the folders in `scripts/private-paths.txt` (`design/`, `private/`, `docs/launch/`). This repo stays private. | The private history holds the open art and the notes of a person who is now in a locked pack. A fresh copy cannot leak an old file, and old commit emails do not go public. |
| T56 | Release signing without a local Developer ID certificate: archive with the Apple Development identity, then `xcodebuild -exportArchive` with `signingStyle automatic` and `-allowProvisioningUpdates`. Xcode signs in the cloud with "Developer ID Application: Zensbot LLC (5PDR77PRWF)". `notarytool` uses the keychain profile `axo-notary` (Apple ID with an app-specific password from `~/.secrets`). The unsigned DMG is not notarized: the app inside has its own ticket, and Apple took more than 6 hours for a DMG (`AXO_NOTARIZE_DMG=1` sends it). | The certificate private key stays at Apple, so it cannot get lost or leak from this Mac. Hassan does not need to make a certificate or an API key. |
