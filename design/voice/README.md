# Voice lines

The buddy's spoken lines. The text is in `lines.tsv` (one row per line: `id`, then `text`).
The app plays `App/Resources/Voice/<id>.m4a`. `scripts/make-voice.py` makes those files with ElevenLabs.

## What was used (made 2026-10-22)

| Item | Choice |
|---|---|
| Model | `eleven_v4` (Eleven v4). The newest and best-quality text-to-speech model on the account. ElevenLabs says it beats Eleven v3 on quality, consistency and emotion. |
| Voice | **Kristen - Calm, Comforting, Meditative**, id `KGZeK6FsnWQdrkDHnDNA`, from the ElevenLabs voice library |
| Why this voice | Soft, slow and warm, made for guided meditation and wellness apps. Neutral American accent, so people who learned English as a second language understand it. Of 8 calm voices tested on Eleven v4, it was one of the slowest and loudest, and speech-to-text got every word right. |
| Settings | stability 0.75 (same calm delivery on every line), similarity 0.8, language `en`, seed 7 (next seed on each retry). Eleven v4 has no style, speed or speaker boost settings. |
| Download format | `wav_48000`: uncompressed WAV, 48 kHz, 16-bit, mono. The best format the plan allows. Kept in `design/voice/raw/` (not in git). |
| App format | AAC in `.m4a`, 192 kbps, made with macOS `afconvert`. |
| Check | Each file is sent to ElevenLabs speech-to-text (`scribe_v2`) and the words are compared with the text. A line that differs is made again, at most 2 more times. |
| Result | 53 files, 246 seconds in total (1.7 to 8.0 s each), 6.0 MB. All 53 passed the check on the first take. |
| Characters used | 3,032 for the 53 lines. About 3,000 more went on choosing the voice and settings (6,016 in total). |

## Make lines

The key comes from `~/.secrets`. It is never printed.

```sh
export ELEVENLABS_API_KEY="$(grep -m1 '^ELEVENLABS_API_KEY=' ~/.secrets/env/shared.env | cut -d= -f2- | tr -d '"')"
scripts/make-voice.py                      # every line that has no .m4a yet
scripts/make-voice.py step-wrist streak    # make these lines again (after a text change, for example)
```

To change a line's words: edit `lines.tsv`, then run the script with that id.
To add a line: add a row to `lines.tsv` and the same id to `VoiceLine` in BuddyCore.

## Change the voice

The first request with a library voice adds it to the account's "My Voices". If its owner later takes it
off the library, the account can still use it for 2 years. The files already made are not affected.

1. Find a voice in the ElevenLabs voice library and copy its id.
2. In `scripts/make-voice.py`, set `VOICE_ID`, `VOICE_NAME` and the one-line reason above them.
3. Delete `App/Resources/Voice/*.m4a` and run `scripts/make-voice.py`. All lines must use the same voice.
4. Update the table above.
