<!-- Source text of the public notice at https://axo.zensbot.com/privacy (site/privacy.html). Keep the two the same. -->

# Axo privacy notice

Effective date: the day of the first public release.

Axo is a free, open-source Mac app made by Hassan Arshad. It helps with posture and breaks. In this notice, "we" means Hassan Arshad. The installer shows "Zensbot LLC" because the app is signed with the Zensbot LLC Apple Developer ID.

## The short version

- Axo works on your Mac. Camera frames are checked in memory and dropped. They are never saved or sent, unless you turn on progress photos, which stay on your Mac.
- There is no account and no cloud sync. Your settings and history stay on your Mac.
- Axo makes two kinds of network calls: an update check, and anonymous usage counts. You can turn the counts off.
- This website has no cookies, no analytics and no trackers.

## What the app keeps on your Mac

Axo keeps your settings, your buddy (its name and color), your reminders and your history on your Mac, in `~/Library/Application Support/Axo` and in Axo's settings file. iCloud sync is off for them. Axo does not send any of this anywhere.

Your history holds results only: the time and result of each posture check (such as "good" or "head dropped"), your reminders and breaks (shown, done, snoozed or finished), your minutes at the Mac each day, and your buddy's level. It never holds a picture or a body measurement. Each check and reminder event is deleted after 90 days. The daily totals stay, so your buddy keeps its level. "Delete history…" in the Progress window deletes all of it.

Your own backups, such as Time Machine, may include your settings and history, as they do for any app. Progress photos are left out of Time Machine.

## Camera

- Axo uses the camera to check your posture. Apple's on-device body pose detection finds your head and shoulders in each frame.
- Each frame is checked in memory on your Mac and then dropped. Frames are never saved or sent, unless you turn on progress photos (see below).
- The camera runs for about 3 seconds each minute, and only while you are at the Mac. On a built-in camera, the green camera light shows each check.
- When you have not used the keyboard or mouse for about 100 seconds, Axo may look with the camera for up to 3 seconds to see if a person is still there, for example because you are reading. While it sees you, it looks again once a minute. If it sees nobody, it treats you as away and stops looking until you use the Mac again. It never looks during a call, a break or a pause, or while the screen is locked.
- Axo keeps only the result of each check, such as "good" or "head dropped", with the time. This stays on your Mac.
- You can turn the camera off in Axo's Settings, or remove its access in System Settings > Privacy & Security > Camera. Reminders still work.

## Progress photos

- Off by default. Nothing is saved until you turn them on in Settings.
- When they are on: at most one photo a day, plus at most one photo a day when your posture is bad.
- They are stored only on your Mac, in `~/Library/Application Support/Axo/Photos`. Axo never sends them anywhere.
- Axo copies a camera frame only while this switch is on.
- Only your Mac user account can open the folder. It is left out of Time Machine backups. The photo files hold no location or camera details (metadata).
- Each photo is deleted after 30 days. One button deletes all of them at once.

## AirPods

If you turn this on and wear supported AirPods or headphones, Axo reads head motion during the same short checks. It uses only the angle of your head. macOS asks for your permission first. The readings are not sent anywhere.

## Microphone

Axo never listens to your microphone and does not ask for microphone access. To pause reminders during calls, it only asks macOS whether another app is using a microphone.

## Voice

The voice lines were made once, before release, and ship inside the app. Axo plays them on your Mac. It does not record your voice, and it sends no audio anywhere. The voice stays quiet during calls and while any app uses a microphone.

## Network calls

Axo makes exactly two kinds of network calls. Nothing else in the app uses the network.

### 1. Update check

- **What it does:** Axo uses Sparkle, an open-source update tool, to check for new versions. It downloads a list of versions from `https://axo.zensbot.com/appcast.xml`. It checks once a day, and when you click "Check for Updates…" in the menu. You can turn the daily check off in Settings > General. When you install a new version, Axo downloads it from the link in that list (Axo's releases on GitHub).
- **What it sends:** only what any web request sends: your IP address, and the app's name and version. Axo does not send Sparkle's optional system profile, so no details about your Mac are sent with it.
- **Who receives it:** Cloudflare, which hosts axo.zensbot.com, and GitHub, which hosts the update file.

### 2. Anonymous usage counts

- **What it does:** Axo sends anonymous counts to TelemetryDeck, to learn how the app is used, for example how many people use eye rest. This is on by default, and starts only after you finish the setup window. You can turn it off with "Share anonymous usage counts", in the setup window or in Settings > General. When it is off, Axo sends no counts and deletes its random ID (see below).
- **What it sends:** only these events: "app started", "reminder done" and "reminder snoozed" (with the kind of reminder, such as eye rest), "break finished" (with the kind), "setup finished" and "buddy picked" (with the buddy's id, such as "25-axo-axolotl", or "locked" for a secret buddy). Axo makes each count itself. It does not use TelemetryDeck's software, so nothing is added to the list below.
- **What comes with each event:** the app version and build, the macOS version (such as "15.1"), the chip type (Apple or Intel), the time the event happened, and whether this is a test build. Each count also has two random IDs. One is made on your Mac the first time a count is sent. It is scrambled (hashed) before it leaves your Mac, so TelemetryDeck can count people without knowing who they are. The other is new each time Axo starts. Neither ID is linked to your name, your Apple account or your Mac's serial number. When you turn the counts off, Axo deletes the first ID. If you turn the counts on again, Axo makes a new one.
- **When it is sent:** at once. If your Mac is offline, the count waits in memory and goes with the next one. Counts that wait are deleted when Axo quits. Nothing is saved in a file for later.
- **What it never sends:** your name, email, photos, camera frames, posture readings or the text of your reminders.
- **Who receives it:** TelemetryDeck (`nom.telemetrydeck.com`), which processes the counts for us. Like any web request, the connection shows your IP address to TelemetryDeck's servers.

## This website

axo.zensbot.com is a static website on Cloudflare Pages. It has no cookies, no analytics, no trackers and no third-party scripts.

Cloudflare serves the pages, so it receives your IP address and browser details, like any web host. The Download button and the Homebrew command get the app from GitHub, so GitHub receives that request.

## Children

Axo is made for people who sit at a Mac, not for children. It asks no one for a name, email or age. If a child uses it, everything in this notice applies the same way.

## Changes

If this notice changes, we will post the new text on this page with a new effective date. Every change is public in the history of `docs/PRIVACY-NOTICE.md` in the GitHub repository.

## Contact

Questions or problems: open an issue at https://github.com/hassanarshad123/axo/issues. Issues are public, so do not post private information there.
