# Axo: product spec

Name: **Axo**, after the default buddy, a pink axolotl. Users can pick one of 16 buddies (see [CHARACTER.md](CHARACTER.md)).
Owner: Hassan Arshad. Spec written 2026-10-21 from a 26-question interview. Every answer is in [DECISIONS.md](DECISIONS.md).

## The problem

People who sit at a Mac all day slouch, do not stretch and do not stand up. The result is neck and back pain.
Nothing reminds them at the right time, in a kind way.

## The product

A free macOS app. A calm, cute buddy lives in the MacBook notch, like the iPhone Dynamic Island.

- It watches your posture with the camera and your AirPods, and tells you gently when you slouch.
- It reminds you to stand up, stretch, rest your eyes and drink water.
- It shows the stretches itself, with an animation and a voice.
- It grows and levels up when you look after yourself.

Hassan uses it first. Then it is given away for free, branded Hassan Arshad.

```
   ┌──────── menu bar ────────┬── notch ──┬──────── menu bar ────────┐
                     [ (•‿•) ]███████████[ 24m ]      ← compact island
                     ┌────────────────────────────┐
                     │ (•‿•)  Stand up             │  ← expanded island
                     │        You have been...     │     (reminder or nudge)
                     │        [Done] [Snooze 5m]   │
                     └────────────────────────────┘
```

## Users

1. **Hassan.** Long days at the Mac, neck pain, wants a reminder that works.
2. **Anyone with a Mac who sits a lot.** Developers, designers, students, remote workers. They get it free.

## Features

### 1. The buddy in the notch
- Lives in the notch on MacBooks with a notch.
- On Macs or monitors with no notch: a fake black island at the top center that looks and works the same.
- Compact view: buddy face on the left, time to the next reminder on the right.
- Expanded view: grows down to show a reminder or a posture nudge, with Done and Snooze.
- The buddy's face shows its mood: happy, calm, worried, asleep, stretching, celebrating.
- Character style: a cute animated character. This is the brand. Hassan picks it from 15 options.

### 2. Posture check
- **Camera:** Apple's on-device body-pose AI looks at head and shoulders. It runs for about 3 seconds each minute, then the camera turns off. The green camera light blinks on each check.
- **AirPods:** head motion from AirPods Pro, AirPods Max and other supported headphones. A backup when the camera is off or you are out of frame.
- **Calibration:** at first start you sit straight for 5 seconds. That is your "good posture".
- **Learns over time:** good readings move the baseline a little, so it fits your body and desk.
- It checks for: head dropped, leaning in toward the screen, leaning to one side, head tilted down.
- It speaks up only after 2 bad checks in a row, so one bad second does not nag you.

### 3. Alerts when posture is bad
- The menu bar icon changes.
- A notification banner (can turn off).
- A sound or a voice line (can turn off).
- The buddy in the notch looks worried.

### 4. Reminders
- Built in: stand up (every 30 min), rest your eyes (20-20-20, every 20 min), stretch (every 60 min), drink water (every 60 min).
- **Fully customizable.** Each person can change times, turn reminders off and add their own reminders.
- Strictness: the user picks. Default is gentle (notch only). Options: full-screen break with Skip, or full-screen locked break.
- Sitting reminders count only while you are at the Mac. A 5-minute break away from the Mac starts them again.
- Water counts real time, also when you are away.

### 5. Auto pause
- **When you leave the Mac:** no keyboard or mouse for 2 minutes.
- **During calls:** if Zoom, Meet, Teams or FaceTime uses the mic, reminders wait until the call ends.
- Not chosen for v1: full-screen video pause, Mac Focus mode pause.

### 6. Stretches
- The buddy does each stretch in a short animation, and the voice counts.

### 7. Voice
- Tone: **calm coach.** Soft and kind, like a yoga teacher. Example: "Take a slow breath and lift your head."
- About 50 short voice lines, made once with ElevenLabs and shipped inside the app. Works offline.

### 8. Progress
- Daily posture score (0 to 100).
- Streaks (days in a row at or above the goal).
- Weekly charts (posture, sitting time, breaks).
- The buddy grows and levels up when you do well.

### 9. Progress photos (opt-in)
- Off by default. When the user turns it on: one photo a day plus one when posture is bad.
- Saved only on this Mac. Deleted after 30 days.

## Rules that do not change

- Camera frames are checked on the Mac and dropped at once, unless the user turns on progress photos.
- No account. No cloud sync. Settings and history stay on the Mac.
- Usage data: anonymous counts only (for example "how many people use eye rest"). Needs a short privacy notice before launch.
- English only in v1. All text sits in one place, so other languages are easy later.
- Free forever. No payments.

## Platform and release

| Item | Choice |
|---|---|
| Tech | Native Swift + SwiftUI, Apple Vision, CoreMotion |
| macOS | 14 Sonoma and newer |
| Download | Signed `.dmg` on a website and on GitHub, plus Homebrew. Auto-update. |
| Apple account | Zensbot LLC Developer ID. The install screen shows "Zensbot LLC". Brand shows Hassan Arshad. |
| Code | Private now. Open source (MIT) at launch. |
| Build plan | Build all features, then Hassan starts to use it. |

## Open questions (later)

- Final app name (after the character pick).
- Website domain for the download page.
- Wording of the privacy notice (Hassan must approve before it is published).
