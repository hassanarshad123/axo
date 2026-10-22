#!/usr/bin/env bash
# Packs Axo.app into a compressed DMG with an Applications link, so the user drags one onto the other.
#
#   scripts/make-dmg.sh <path/to/Axo.app> <out.dmg>
#
# scripts/release.sh signs and notarizes the DMG after this.
set -euo pipefail

APP="${1:?Give the path to Axo.app}"
DMG="${2:?Give the path for the DMG}"
[[ -d "$APP" ]] || {
  echo "STOP: $APP is not an app folder." >&2
  exit 1
}

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT

ditto "$APP" "$staging/Axo.app"
ln -s /Applications "$staging/Applications"
rm -f "$DMG"
hdiutil create -quiet -volname "Axo" -srcfolder "$staging" -fs HFS+ -format UDZO -ov "$DMG"
hdiutil verify -quiet "$DMG"
echo "DMG: $DMG ($(du -h "$DMG" | cut -f1))"
