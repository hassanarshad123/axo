#!/usr/bin/env bash
# Make one image with Codex image generation (uses the ChatGPT login of `codex`).
#
# Usage: scripts/codex-image.sh <output.png> "<image brief>" [reference.png]
# Example: scripts/codex-image.sh design/buddy/happy.png "The attached buddy, smiling, on pure black" design/pick.png
#
# The optional reference image is attached to the prompt, so the new image keeps the same character and style.
# About 1 minute per image. Run up to 4 at the same time with xargs -P 4.
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <output.png> \"<image brief>\" [reference.png]" >&2
  exit 64
fi

REF_ARGS=()
if [[ $# -eq 3 ]]; then
  [[ -f "$3" ]] || { echo "Reference image not found: $3" >&2; exit 66; }
  REF_ARGS=(-i "$3")
fi

command -v codex >/dev/null || { echo "codex CLI not found. Install it and run 'codex login'." >&2; exit 69; }

OUT="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
BRIEF="$2"
LOG="${OUT%.png}.codex.log"

PROMPT="Use your built-in image generation tool to create exactly ONE image, then save it as a PNG file at this exact path: ${OUT}
Do not create any other files. Do not write code to draw the image. When the file is saved, print the path and stop.

Image brief:
${BRIEF}"

# The prompt goes before -i, because -i takes a list of files and would eat the prompt.
codex exec --skip-git-repo-check -C "$(dirname "$OUT")" "$PROMPT" ${REF_ARGS[@]+"${REF_ARGS[@]}"} > "$LOG" 2>&1 || true

if [[ -s "$OUT" ]]; then
  rm -f "$LOG"
  echo "OK   $OUT"
else
  echo "FAIL $OUT (log: $LOG)" >&2
  exit 1
fi
