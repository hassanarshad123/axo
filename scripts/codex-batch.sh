#!/usr/bin/env bash
# Make every image in a briefs folder that does not exist yet, 4 at a time, with Codex.
#
# Usage: scripts/codex-batch.sh <briefs-dir> <out-dir> [slug ...]
#   <briefs-dir>/<slug>.txt  the image brief (required)
#   <briefs-dir>/<slug>.ref  one line: a reference image path, relative to the repo root (optional)
# Writes <out-dir>/<slug>.png. Delete an output to make it again. Give slugs to make only those.
set -euo pipefail

REPO="$(cd "$(dirname "$0")/.." && pwd)"
BRIEFS="$(cd "$1" && pwd)"
OUT="$(mkdir -p "$2" && cd "$2" && pwd)"
shift 2

make_one() {
  local slug="$1" brief="$BRIEFS/$1.txt" ref="$BRIEFS/$1.ref"
  [[ -f "$brief" ]] || { echo "FAIL $slug (no brief)"; return 1; }
  [[ -s "$OUT/$slug.png" ]] && { echo "SKIP $slug (exists)"; return 0; }
  if [[ -f "$ref" ]]; then
    "$REPO/scripts/codex-image.sh" "$OUT/$slug.png" "$(cat "$brief")" "$REPO/$(head -1 "$ref")"
  else
    "$REPO/scripts/codex-image.sh" "$OUT/$slug.png" "$(cat "$brief")"
  fi
}
export -f make_one
export REPO BRIEFS OUT

if [[ $# -gt 0 ]]; then
  printf '%s\n' "$@"
else
  find "$BRIEFS" -name '*.txt' -exec basename {} .txt \; | sort
fi | xargs -P 4 -I{} bash -c 'make_one "$@" || true' _ {}
