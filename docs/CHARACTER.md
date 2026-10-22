# The buddy character

The character is the brand. Hassan picks it. All art is made with Codex image generation (gpt-image, through Hassan's ChatGPT login).

## Step 1: options (done 2026-10-21)

15 options in `design/character-options/`. Open `design/character-options/index.html` to compare them.
Each sheet shows the full character, then three moods: happy, worried, asleep.
`design/character-options/heroes/` has each character cut out, to test it at notch size.

| # | Working name | Style | Creature |
|---|---|---|---|
| 01 | Nubo | Soft 3D | Cloud |
| 02 | Pip | Soft 3D | Bean |
| 03 | Shelly | Soft 3D | Turtle |
| 04 | Bolt | Soft 3D | Robot |
| 05 | Mochi | Flat vector | Blob |
| 06 | Hoot | Flat vector | Owl |
| 07 | Beep | Flat vector | Robot |
| 08 | Sprout | Flat vector | Bean with a leaf |
| 09 | Goo | Pixel art | Slime |
| 10 | Neko | Pixel art | Cat |
| 11 | Bit | Pixel art | Robot |
| 12 | Kumo | Kawaii | Cloud |
| 13 | Slo | Kawaii | Sloth |
| 14 | Pengu | Kawaii | Penguin |
| 15 | Tiko | Kawaii | Robot |

Rules every option had to meet: calm and kind, reads at 32 px tall, big eyes, 3 to 4 main colors, works on the black notch, no text.

## Step 1b: pixel art options (done 2026-10-21)

Hassan asked for more pixel art, and to see how the buddy shows things in the app.
`design/pixel-options/` has 15 pixel characters. Each one has a sheet with 8 poses, one pose for each job in the app.
Open `design/pixel-options/index.html`: a fake MacBook screen plays each app moment in the notch with the character you pick.
A link can open one moment directly, for example `index.html#s=stand&c=19-pengu-penguin`.

| # | Working name | Creature | Note |
|---|---|---|---|
| 09 | Goo | Slime | Same slime as option 09 |
| 10 | Neko | Cat | Same cat as option 10 |
| 11 | Bit | Robot | Same robot as option 11 |
| 16 | Sprout | Bean with a leaf | Pixel version of 08 |
| 17 | Nubo | Cloud | Pixel version of 01 |
| 18 | Shelly | Turtle | Pixel version of 03 |
| 19 | Pengu | Penguin | Pixel version of 14 |
| 20 | Slo | Sloth | Pixel version of 13 |
| 21 | Hoot | Owl | Pixel version of 06 |
| 22 | Mochi | Dumpling | Pixel version of 05 |
| 23 | Kero | Frog | New |
| 24 | Usa | Bunny | New |
| 25 | Axo | Axolotl | New |
| 26 | Moni | Tiny computer | New |
| 27 | Hammy | Hamster | New |

The 8 poses and their jobs:

| Pose | Job in the app |
|---|---|
| happy | Good posture. The normal face in the notch |
| worried | The user slouches. The buddy copies the bad posture |
| sleeping | User away, in a call, or paused |
| stretching | Stand-up reminder, stretch breaks |
| neck | Neck stretch, done together with the user |
| water | Water reminder |
| eyes | Eye rest (look 20 feet away for 20 seconds) |
| celebrate | Level up, streak, a finished break |

How the files were made:

1. `design/pixel-options/prompts.tsv` holds one line per character: the slug, an optional reference image and the character text.
2. Codex makes one 4 x 2 sheet per character on black (`scripts/codex-image.sh`, with the reference image for 09, 10 and 11).
3. `scripts/split-sprite-sheet.py <sheet> <out-dir>` cuts each sheet into 8 poses in `design/pixel-options/sprites/<slug>/`. All poses get one frame size and one baseline, and the black around the character becomes transparent.

These are AI images in a pixel style. They have no exact pixel grid (a test found that only about 20% of the edges fit one grid). So the app does not show them with hard pixel scaling. The export shrinks them smoothly to 192 px tall, which looks clean at the island sizes (26 pt and 92 pt). A redraw on a true grid stays an option for later.

## Step 2: the pick (done 2026-10-21)

- **Axo (25, the pink axolotl)** is the brand: app name, app icon, website and the default buddy.
- **Every user picks a buddy** from 16: the 15 pixel buddies above plus **Hassan (29)**.
  - Hassan is Hassan himself: a nerdy desi young man with a heavy black fringe and clear glasses. He asked for his photo to go to Codex as the reference for his pose sheet (DECISIONS #38).
  - More buddies are in locked packs. A code opens them (DECISIONS #54, T54). Pack 1 holds buddy 28 (#36) and the duo, buddy 30 (#39). Besides the core poses the duo has a "moments" sheet: wave, walk, laptop, chai, thumbs-up, fist bump, breathe, trophy.
- **Customize:** name, color and (later) voice. The color option turns only the buddy's main color. Voice uses ElevenLabs, which costs credits, so it waits for a yes on the budget.
- **Levels:** the buddy grows through 5 forms, like a creature-collecting game: baby, normal, evolved, champion, legend.
- **Menu bar icon:** the user picks a one-color outline (macOS colors it to match the menu bar) or the color head.

## Step 3: the full asset set

Every buddy gets the same set, made with Codex from its own pose sheet as the reference, so the style matches.

| Sheet | Images | Used in |
|---|---|---|
| core (from Step 1b) | happy, worried, sleeping, stretching, neck, water, eyes, celebrate | Island moods and reminders |
| moods-2 | calm, blink, talking, curious, wave, thumbs-up, sad, yawn | Idle animation (blink), speech, onboarding |
| stretches-1 | neck-left, neck-right, chin-tuck, shrug, chest-open, twist-left, twist-right, wrist | Stretch routines |
| stretches-2 | reach, side-bend, march, walk, breathe, palming, sit-tall, slouch | Stretch routines, posture tips |
| moments (the duo only) | wave, walk, laptop, chai, thumbs-up, fist-bump, breathe, trophy | Same names as the single buddies' poses, so the app uses them the same way |
| evolution | form1 to form5 (one row, the forms grow left to right) | Levels screen |
| form1/3/4/5-poses | the 8 core poses for each form (form 2 is the normal buddy) | Island after a level up |
| menubar-color, menubar-outline | the head, 36 px (18 pt) | Menu bar |

Brand images for Axo only, in `design/axo/source/`: 3 app icon artworks (navy, mint, notch), 4 onboarding screens (welcome, calibrate, privacy, AirPods) and 3 release images (DMG background, website hero, social card).

### The pipeline

```
prompts.tsv ─► make-buddy-briefs.py 1 ─► codex-batch.sh ─► design/buddies/source/<slug>--<sheet>.png
                                                                    │
                                    export-buddy-assets.py ◄────────┘  cuts every sheet into
                                                │                      design/buddies/cuts/<slug>/<sheet>/
                                                ▼
             Packages/BuddyKit/Sources/NotchUI/Resources/Buddies/<slug>/<image>.png + catalog.json
                                                │
          make-buddy-briefs.py 2 ◄──────────────┘  (form references from the cut evolution line)
                     │
                     └─► codex-batch.sh (form pose sheets) ─► export-buddy-assets.py again
```

1. `scripts/make-buddy-briefs.py 1` writes 6 briefs per buddy into `design/buddies/briefs/` (`<slug>--<sheet>.txt`, plus a `.ref` file with the reference image).
2. `scripts/codex-batch.sh design/buddies/briefs design/buddies/source` makes every image that does not exist yet, 4 at a time. To make one again, delete it and run the batch again.
3. `scripts/export-buddy-assets.py` cuts the core pose sheet (`design/pixel-options/<slug>.png`) and every other sheet, shrinks every image to 192 px tall with 128 colors, makes the menu bar icons and writes `catalog.json` (id, number, name, color settings). It replaces the whole `Buddies` folder each time. A buddy whose core sheet is missing is left out, with a warning.
4. `scripts/make-buddy-briefs.py 2` puts each cut form on black as the reference and writes the form pose briefs. Then run steps 2 and 3 again.

Each pixel of an exported image is solid or see-through, never half. The cut counts brightness 0 to 4 as background (Codex draws the black at 0 to 2). A higher value ate dark hair and outlines.

Pose sheets are cut by grid cells, but each whole shape goes to the cell that holds most of it, so a tail or a sparkle that reaches over a cell line stays with its own sprite. The evolution line is cut by shapes (`--by-shapes`, see `scripts/sprite_shapes.py`), not by equal cells. The forms grow from left to right, and whiskers or tails of one form can reach over the next one. Loose sparkles join the nearest form. If a faint glow joins two forms, the cut tries again with brighter cut-offs. If two forms still touch, the cut stops with a message: make that sheet again.

### Color settings

`design/buddies/buddy-settings.json` holds the name and the color settings of each buddy. The export copies them into `catalog.json`, and the app's `HueSwap` uses them:

| Field | Default | What it does |
|---|---|---|
| `mainHue` | most common strong hue | The turn starts here: a color choice turns this hue to its target |
| `hueCenter`, `hueTolerance` | `mainHue`, 30 | Hues within the tolerance of the center turn |
| `minSaturation` | 0.12 | Paler pixels keep their color (white, cream, blush) |
| `minValue` | 0 | Darker pixels keep their color (eyes, outlines, shadows) |

Each limit has a soft edge, so the pixels near a limit turn only part of the way. Before you ship a change, run the export, then draw every buddy in every color:

```
scripts/color-sheet.py /tmp/colors.png                 # all buddies
scripts/color-sheet.py /tmp/neko.png 10-neko-cat       # one buddy
```

A gray frame marks a color that the app does not offer for that buddy: it is within 25° of the buddy's own color. The test "Every buddy turns part of its art" fails when a buddy's settings turn almost nothing.

`scripts/make-app-icon.py <artwork> App/Resources/Assets.xcassets/AppIcon.appiconset` turns the chosen icon artwork into all macOS icon sizes.

## How to make more images

`scripts/codex-image.sh <out.png> "<brief>" [reference.png]` asks Codex for one image. It runs:

```
codex exec --skip-git-repo-check -C <output folder> "<prompt>" -i <reference.png>
```

Put the prompt before `-i`. About 1 minute per image. 4 runs at the same time work well (`codex-batch.sh` does this). If Codex fails with `refresh_token_invalidated`, run `codex login` again.

To add a new buddy: add a line to `design/pixel-options/prompts.tsv`, make its core sheet as `design/pixel-options/<slug>.png`, add its settings to `buddy-settings.json`, then run the pipeline above. If the buddy is based on a real person, get their consent first. Describe them in text. Send their photo to Codex only when that person asks for it.
