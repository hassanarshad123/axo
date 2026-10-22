#!/usr/bin/env python3
"""Make the buddy's voice lines with ElevenLabs.

Usage: ELEVENLABS_API_KEY=... scripts/make-voice.py [id ...]
Reads design/voice/lines.tsv (columns: id, text). With ids, it makes those lines again. Without ids,
it makes every line whose App/Resources/Voice/<id>.m4a does not exist yet.
Each line: text to speech (best output format the plan allows) -> design/voice/raw/<id>.<ext>
-> AAC 192 kbps .m4a with macOS afconvert. Then speech to text checks the words. When they differ,
it makes the line again (at most 2 more times) and reports the lines that still differ.
Needs macOS (afconvert, afinfo) and Python 3 only. It never prints the API key.
"""

import argparse
import difflib
import io
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid
import wave
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
LINES = REPO / "design/voice/lines.tsv"
RAW = REPO / "design/voice/raw"
OUT = REPO / "App/Resources/Voice"
API = "https://api.elevenlabs.io"

# Checked 2026-10-22 with GET /v1/models: eleven_v4 is listed for this account and does text to speech in English.
# ElevenLabs calls it its "latest and most advanced" model: better quality, consistency and emotion than eleven_v3.
MODEL_ID = "eleven_v4"
# Checked 2026-10-22: the API lists scribe_v1, scribe_v1_experimental, scribe_v2 and scribe_v2_medical. v2 is the newest.
STT_MODEL_ID = "scribe_v2"

# "Kristen - Calm, Comforting, Meditative" from the ElevenLabs voice library: a soft, slow, warm American voice
# with a neutral accent, made for guided meditation and wellness apps; eleven_v4 is one of its high-quality models.
VOICE_ID = "KGZeK6FsnWQdrkDHnDNA"
VOICE_NAME = "Kristen - Calm, Comforting, Meditative"

# eleven_v4 takes stability and similarity only (no style, speed or speaker boost). High-ish stability keeps all
# lines in the same calm delivery. A fixed seed makes a run repeatable; each retry uses the next seed.
VOICE_SETTINGS = {"stability": 0.75, "similarity_boost": 0.8}
SEED = 7
LANGUAGE = "en"

# Best first. 44.1 kHz and up need a Pro plan; mp3 at 192 kbps needs Creator. The first one that works is used.
OUTPUT_FORMATS = ("wav_48000", "pcm_48000", "wav_44100", "pcm_44100", "mp3_44100_192")
AAC_BITRATE = 192_000
MAX_RETRIES = 2
MAX_SECONDS = 15.0
HTTP_TRIES = 4  # for 429 and 5xx answers

ONES = (
    *("zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine"),
    *("ten", "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen"),
)
TENS = ("", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety")
SPELLING = {"ok": "okay", "levelled": "leveled"}


class ApiError(Exception):
    def __init__(self, status: int, detail: str) -> None:
        super().__init__(f"HTTP {status}: {detail}")
        self.status = status


def api_key() -> str:
    key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not key:
        sys.exit("ELEVENLABS_API_KEY is not set. Put the ElevenLabs API key in that environment variable.")
    return key


def request(key: str, path: str, body: bytes | None = None, content_type: str = "") -> tuple[bytes, dict]:
    """Calls the API and returns (body, headers). Retries on 429 and 5xx. Exits on 401."""
    headers = {"xi-api-key": key, "Accept": "*/*"}
    if content_type:
        headers["Content-Type"] = content_type
    for attempt in range(HTTP_TRIES):
        try:
            with urllib.request.urlopen(urllib.request.Request(API + path, body, headers), timeout=180) as response:
                return response.read(), dict(response.headers)
        except urllib.error.HTTPError as error:
            detail = error.read()[:400].decode(errors="replace")
            if error.code == 401:
                sys.exit("ElevenLabs refused the API key (HTTP 401). Check ELEVENLABS_API_KEY.")
            if (error.code != 429 and error.code < 500) or attempt == HTTP_TRIES - 1:
                raise ApiError(error.code, detail) from None
        except urllib.error.URLError as error:
            if attempt == HTTP_TRIES - 1:
                raise ApiError(0, str(error.reason)) from None
        time.sleep(2**attempt * 2)
    raise AssertionError("unreachable")


def check_model(key: str) -> None:
    models = json.loads(request(key, "/v1/models")[0])
    model = next((m for m in models if m.get("model_id") == MODEL_ID), None)
    if not model or not model.get("can_do_text_to_speech"):
        sys.exit(f"{MODEL_ID} is not available for text to speech on this account. Check GET /v1/models.")


def read_lines() -> dict[str, str]:
    rows = LINES.read_text().splitlines()
    if not rows or rows[0] != "id\ttext":
        sys.exit(f"{LINES} must start with the header row 'id<TAB>text'.")
    lines: dict[str, str] = {}
    for number, row in enumerate(rows[1:], start=2):
        parts = row.split("\t")
        if len(parts) != 2 or not parts[0].strip() or not parts[1].strip():
            sys.exit(f"{LINES}:{number}: need exactly 2 columns, id and text.")
        if parts[0] in lines:
            sys.exit(f"{LINES}:{number}: id {parts[0]} is there twice.")
        lines[parts[0]] = parts[1].strip()
    return lines


def speak(key: str, text: str, seed: int, formats: tuple[str, ...]) -> tuple[bytes, str, int]:
    """Tries the formats best first. Returns (audio, the format that worked, characters charged)."""
    body = {"text": text, "model_id": MODEL_ID, "language_code": LANGUAGE, "voice_settings": VOICE_SETTINGS}
    payload = json.dumps({**body, "seed": seed}).encode()
    for index, output_format in enumerate(formats):
        path = f"/v1/text-to-speech/{VOICE_ID}?output_format={output_format}"
        try:
            audio, headers = request(key, path, payload, "application/json")
        except ApiError as error:
            if error.status not in (400, 403) or index == len(formats) - 1:
                raise
            print(f"  {output_format} not allowed ({error}), trying {formats[index + 1]}")
            continue
        return audio, output_format, int(headers.get("character-cost") or len(text))
    raise AssertionError("no output format given")


def as_file(audio: bytes, output_format: str) -> tuple[bytes, str]:
    """Raw PCM gets a WAV header so afconvert can read it. Returns (file bytes, extension)."""
    kind, _, rate = output_format.partition("_")
    if kind == "mp3":
        return audio, "mp3"
    if kind == "wav":
        return audio, "wav"
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(int(rate))
        out.writeframes(audio)
    return buffer.getvalue(), "wav"


def transcribe(key: str, data: bytes, extension: str) -> str:
    boundary = uuid.uuid4().hex
    fields = {"model_id": STT_MODEL_ID, "language_code": LANGUAGE, "tag_audio_events": "true"}
    head = f"--{boundary}\r\nContent-Disposition: form-data; name="
    form = "".join(f'{head}"{name}"\r\n\r\n{value}\r\n' for name, value in fields.items())
    file_head = (
        f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="line.{extension}"\r\n'
        "Content-Type: application/octet-stream\r\n\r\n"
    )
    payload = (form + file_head).encode() + data + f"\r\n--{boundary}--\r\n".encode()
    body, _ = request(key, "/v1/speech-to-text", payload, f"multipart/form-data; boundary={boundary}")
    return json.loads(body).get("text", "")


def number_words(number: int) -> list[str]:
    if number < 20:
        return [ONES[number]]
    return [TENS[number // 10]] + ([ONES[number % 10]] if number % 10 else [])


def spoken_words(text: str) -> list[str]:
    """Lower case words without punctuation or sound tags like (sighs); digits become words (20 -> twenty)."""
    text = re.sub(r"\([^)]*\)|\[[^\]]*\]", " ", text.lower().replace("’", "'"))
    result: list[str] = []
    for token in re.findall(r"[a-z0-9']+", text):
        word = token.replace("'", "")
        word = SPELLING.get(word, word)
        result += number_words(int(word)) if word.isdigit() and int(word) < 100 else [word]
    return result


def word_errors(expected: list[str], heard: list[str]) -> int:
    matcher = difflib.SequenceMatcher(a=expected, b=heard, autojunk=False)
    return sum(max(i2 - i1, j2 - j1) for tag, i1, i2, j1, j2 in matcher.get_opcodes() if tag != "equal")


def duration(path: Path) -> float:
    info = subprocess.run(["afinfo", str(path)], capture_output=True, text=True, check=True).stdout
    match = re.search(r"estimated duration: ([0-9.]+)", info)
    return float(match.group(1)) if match else 0.0


def to_m4a(raw: Path, out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as scratch:
        temp = Path(scratch) / out.name
        command = ["afconvert", "-f", "m4af", "-d", "aac", "-b", str(AAC_BITRATE), "-q", "127", str(raw), str(temp)]
        subprocess.run(command, check=True, capture_output=True)
        temp.replace(out)


def make_line(key: str, line_id: str, text: str, formats: tuple[str, ...]) -> tuple[int, str, str]:
    """Makes one line; keeps the take with the fewest word errors. Returns (characters, format used, problem)."""
    characters, best, output_format = 0, None, formats[0]
    for attempt in range(MAX_RETRIES + 1):
        audio, output_format, cost = speak(key, text, SEED + attempt, formats[formats.index(output_format) :])
        characters += cost
        data, extension = as_file(audio, output_format)
        heard = transcribe(key, data, extension)
        errors = word_errors(spoken_words(text), spoken_words(heard))
        if best is None or errors < best[0]:
            best = (errors, data, extension, heard)
        if errors == 0:
            break
        print(f"  take {attempt + 1} differs: heard {heard!r}")
    errors, data, extension, heard = best
    RAW.mkdir(parents=True, exist_ok=True)
    for old in RAW.glob(f"{line_id}.*"):
        old.unlink()
    raw = RAW / f"{line_id}.{extension}"
    raw.write_bytes(data)
    out = OUT / f"{line_id}.m4a"
    to_m4a(raw, out)
    seconds = duration(out)
    problems = [f"heard {heard!r}"] if errors else []
    if not 0 < seconds < MAX_SECONDS:
        problems.append(f"duration {seconds:.2f} s")
    print(f"{line_id:26} {seconds:5.2f} s  {'ok' if not problems else 'CHECK: ' + '; '.join(problems)}")
    return characters, output_format, "; ".join(problems)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("ids", nargs="*", help="line ids to make again (default: every line without an .m4a)")
    args = parser.parse_args()
    lines = read_lines()
    unknown = [line_id for line_id in args.ids if line_id not in lines]
    if unknown:
        sys.exit(f"Unknown line ids: {', '.join(unknown)}. See {LINES}.")
    todo = args.ids or [line_id for line_id in lines if not (OUT / f"{line_id}.m4a").exists()]
    if not todo:
        print("Every line already has an .m4a. Pass ids to make lines again.")
        return
    key = api_key()
    check_model(key)
    print(f"Making {len(todo)} lines with {MODEL_ID}, voice {VOICE_NAME}.")
    formats, characters, failed = OUTPUT_FORMATS, 0, {}
    for line_id in todo:
        cost, used, problem = make_line(key, line_id, lines[line_id], formats)
        formats = formats[formats.index(used) :]  # later lines skip the formats the plan refused
        characters += cost
        if problem:
            failed[line_id] = problem
    print(f"Done: {len(todo)} lines, {characters} characters charged, output format {formats[0]}.")
    for line_id, problem in failed.items():
        print(f"Still differs: {line_id}: {problem}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
