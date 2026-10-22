#!/usr/bin/env bash
# Locks each private/packs/<pack>/ folder into the app as Resources/Packs/<pack>.axopack (DECISIONS T54).
#
#   private/packs/pack-01/ (catalog.json + art) ──AXO_PACK_01_CODE──▶ NotchUI/Resources/Packs/pack-01.axopack
#
# The code of each pack is in ~/.secrets (component axo, key AXO_<PACK>_CODE). Make a new code with
# `swift run --package-path Packages/BuddyKit axo-pack new-code`. Each run makes new locked files
# (new random salt), so run it only after the art of a pack changed. Commit the .axopack files.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="Packages/BuddyKit/Sources/NotchUI/Resources/Packs"
SECRETS="$HOME/.secrets/bin/secrets.sh"

fail() {
  printf 'STOP: %s\n' "$*" >&2
  exit 1
}

[[ -d private/packs ]] || fail "No private/packs folder. Only the private repo has the locked art."
mkdir -p "$OUT"
swift build --package-path Packages/BuddyKit --product axo-pack -c release -q

for folder in private/packs/*/; do
  name="$(basename "$folder")"
  key="AXO_$(tr 'a-z-' 'A-Z_' <<<"$name")_CODE"
  code="$(bash "$SECRETS" get axo "$key" 2>/dev/null || true)"
  [[ -n "$code" ]] || fail "No $key in ~/.secrets (component axo)."
  echo "==> $name"
  AXO_UNLOCK_CODE="$code" swift run --package-path Packages/BuddyKit -c release -q axo-pack seal "$folder" "$OUT/$name.axopack"
done
