#!/usr/bin/env bash
# Builds Axo (Release) and installs it in /Applications on this Mac, for daily use (milestone 7).
#
#   scripts/install-local.sh      (or: make install)
#
# The app is signed with the "Apple Development" identity, not ad hoc. macOS ties the camera
# permission to the signature, so a stable identity keeps the permission after each rebuild.
# This build is for this Mac only. Releases use scripts/release.sh (Developer ID + notarization).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

fail() {
  printf '\nSTOP: %s\n' "$*" >&2
  exit 1
}

IDENTITY="${AXO_DEV_IDENTITY:-$(security find-identity -v -p codesigning |
  sed -n 's/.*"\(Apple Development: .*\)"/\1/p' | head -1)}"
[[ -n "$IDENTITY" ]] || fail "No 'Apple Development' certificate in the Keychain. Xcode > Settings > Accounts makes one."
TEAM_ID="$(security find-certificate -c "$IDENTITY" -p | openssl x509 -noout -subject |
  sed -n 's/.*OU *= *\([A-Z0-9]\{10\}\).*/\1/p')"
[[ -n "$TEAM_ID" ]] || fail "Could not read the team id from '$IDENTITY'."

APP="build/Build/Products/Release/Axo.app"
TARGET="/Applications/Axo.app"

echo "==> Build Axo (Release), signed as '$IDENTITY' (team $TEAM_ID)"
xcodegen generate --quiet
xcodebuild -project Axo.xcodeproj -scheme Axo -configuration Release \
  -derivedDataPath build -destination "platform=macOS,arch=$(uname -m)" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" DEVELOPMENT_TEAM="$TEAM_ID" \
  CURRENT_PROJECT_VERSION="$(git rev-list --count HEAD)" \
  build -quiet
codesign --verify --deep --strict "$APP"

echo "==> Install in /Applications"
if pgrep -xq Axo; then
  osascript -e 'tell application id "com.hassanarshad.axo" to quit' >/dev/null 2>&1 || true
  for _ in 1 2 3 4 5; do pgrep -xq Axo || break; sleep 1; done
  pkill -x Axo || true
fi
rm -rf "$TARGET"
ditto "$APP" "$TARGET"
open "$TARGET"
echo "Installed: $TARGET ($(defaults read "$TARGET/Contents/Info" CFBundleShortVersionString), build $(defaults read "$TARGET/Contents/Info" CFBundleVersion))"
