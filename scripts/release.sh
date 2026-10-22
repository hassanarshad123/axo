#!/usr/bin/env bash
# Makes a signed, notarized Axo release on this Mac. See docs/RELEASE.md.
#
#   scripts/release.sh --check 1.0.0   only check that every key and tool is ready
#   scripts/release.sh 1.0.0           make the release in build/release/
#
#   tests ─▶ Release archive ─▶ export with the Developer ID (local or cloud) ─▶ notarize + staple app
#         ─▶ DMG ─▶ (sign, local only) + notarize + staple DMG ─▶ Gatekeeper check
#         ─▶ site/appcast.xml (Sparkle, EdDSA) ─▶ build/release/axo.rb (Homebrew cask)
#
# Nothing here publishes. scripts/publish.sh does that, after Hassan says yes.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT="build/release"
SPARKLE_BIN="build/SourcePackages/artifacts/sparkle/Sparkle/bin"
SPARKLE_KEY="${AXO_SPARKLE_KEY:-$HOME/.secrets/pem/sparkle-axo-eddsa.key}"
NOTARY_PROFILE="${AXO_NOTARY_PROFILE:-axo-notary}"
REPO_URL="https://github.com/hassanarshad123/axo"
SITE_URL="https://axo.zensbot.com"

CHECK_ONLY=0
if [[ "${1:-}" == "--check" ]]; then
  CHECK_ONLY=1
  shift
fi
VERSION="${1:-}"

say() { printf '\n==> %s\n' "$*"; }
fail() {
  printf '\nSTOP: %s\n' "$*" >&2
  exit 1
}

# ---------------------------------------------------------------- checks

missing=()
need() { missing+=("$1"); }

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Give the version, for example: scripts/release.sh 1.0.0"

project_version="$(sed -n 's/^ *MARKETING_VERSION: *"\(.*\)"/\1/p' project.yml)"
[[ "$project_version" == "$VERSION" ]] ||
  need "project.yml has MARKETING_VERSION \"$project_version\". Set it to \"$VERSION\" and commit."

if [[ "${AXO_ALLOW_DIRTY:-0}" != "1" && -n "$(git status --porcelain)" ]]; then
  need "The git tree has changed or new files that are not committed. A release must match a commit."
fi

for tool in xcodegen xcodebuild hdiutil ditto codesign spctl; do
  command -v "$tool" >/dev/null || need "The tool '$tool' is not installed."
done
[[ -x "$SPARKLE_BIN/generate_appcast" ]] || need "Sparkle tools are missing. Run 'make build' once to download them."

# Two ways to sign (docs/DECISIONS.md T56):
#   local: a "Developer ID Application" certificate in the Keychain signs the app and the DMG.
#   cloud: no such certificate here. The archive is signed with "Apple Development", and Xcode
#          signs the export with the team's Developer ID at Apple. The DMG itself stays unsigned.
TEAM_ID="${AXO_TEAM_ID:-5PDR77PRWF}"
identities="$(security find-identity -v -p codesigning)"
IDENTITY="${AXO_SIGN_IDENTITY:-$(sed -n "s/.*\"\(Developer ID Application: .*($TEAM_ID)\)\"/\1/p" <<<"$identities" | head -1)}"
if [[ -n "$IDENTITY" ]]; then
  SIGNING="local"
  ARCHIVE_IDENTITY="$IDENTITY"
else
  SIGNING="cloud"
  ARCHIVE_IDENTITY="$(sed -n 's/.*"\(Apple Development: .*\)"/\1/p' <<<"$identities" | head -1)"
  [[ -n "$ARCHIVE_IDENTITY" ]] ||
    need "No 'Developer ID Application' and no 'Apple Development' certificate in the Keychain. docs/RELEASE.md."
fi

if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  need "No notarytool profile '$NOTARY_PROFILE' in the Keychain. docs/RELEASE.md, 'Notarization'."
fi

[[ -s "$SPARKLE_KEY" ]] || need "The Sparkle private key is not at $SPARKLE_KEY. docs/RELEASE.md, 'Sparkle key'."
[[ -f "docs/release-notes/$VERSION.md" ]] || need "Write the release notes: docs/release-notes/$VERSION.md"

TELEMETRY_ID="${TELEMETRYDECK_APP_ID:-$(bash "$HOME/.secrets/bin/secrets.sh" get axo TELEMETRYDECK_APP_ID 2>/dev/null || true)}"

if ((${#missing[@]})); then
  printf '\nNot ready. Fix these first:\n' >&2
  printf '  - %s\n' "${missing[@]}" >&2
  exit 1
fi

[[ -n "$TELEMETRY_ID" ]] ||
  printf '\nWARNING: no TelemetryDeck app id. This build sends no usage counts. docs/RELEASE.md, "TelemetryDeck app id".\n'

BUILD_NUMBER="$(git rev-list --count HEAD)"
say "Ready: Axo $VERSION (build $BUILD_NUMBER), $SIGNING signing for team $TEAM_ID (archive: '$ARCHIVE_IDENTITY')"
((CHECK_ONLY)) && exit 0

# ---------------------------------------------------------------- build

APP="$OUT/export/Axo.app"
DMG="$OUT/Axo.dmg"
rm -rf "$OUT"
mkdir -p "$OUT"

say "Tests"
make test

say "Release archive"
xcodegen generate --quiet
xcodebuild archive \
  -project Axo.xcodeproj -scheme Axo -configuration Release \
  -archivePath "$OUT/Axo.xcarchive" \
  -derivedDataPath build \
  -clonedSourcePackagesDirPath build/SourcePackages \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$ARCHIVE_IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  TELEMETRYDECK_APP_ID="$TELEMETRY_ID" \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  -quiet

say "Export with the Developer ID ($SIGNING signing)"
if [[ "$SIGNING" == "local" ]]; then
  signing_options="<key>signingStyle</key><string>manual</string>
  <key>signingCertificate</key><string>Developer ID Application</string>"
  export_flags=()
else
  # Xcode asks Apple to sign with the team's cloud Developer ID certificate. This needs the Apple ID
  # in Xcode > Settings > Accounts, with the Admin or Account Holder role in the team.
  signing_options="<key>signingStyle</key><string>automatic</string>"
  export_flags=(-allowProvisioningUpdates)
fi
cat >"$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>developer-id</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>destination</key><string>export</string>
  $signing_options
</dict>
</plist>
PLIST
xcodebuild -exportArchive \
  -archivePath "$OUT/Axo.xcarchive" \
  -exportPath "$OUT/export" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" \
  ${export_flags[@]+"${export_flags[@]}"} \
  -quiet

say "Check the signature"
codesign --verify --deep --strict --verbose=2 "$APP"
signature="$(codesign -dvv "$APP" 2>&1)"
grep -q "Authority=Developer ID Application: .*($TEAM_ID)" <<<"$signature" ||
  fail "The app is not signed with the Developer ID of team $TEAM_ID."
grep -q "flags=.*runtime" <<<"$signature" || fail "The hardened runtime is off."
codesign -d --entitlements - --xml "$APP" 2>/dev/null | grep -q "com.apple.security.device.camera" ||
  fail "The camera entitlement is missing, so the camera would never work."
built_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
[[ "$built_version" == "$VERSION" ]] || fail "The app says version $built_version, not $VERSION."

notarize() {
  local file="$1" result id
  say "Notarize $(basename "$file") (Apple takes a few minutes)"
  result="$(xcrun notarytool submit "$file" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json)"
  id="$(plutil -extract id raw - <<<"$result")"
  if [[ "$(plutil -extract status raw - <<<"$result")" != "Accepted" ]]; then
    xcrun notarytool log "$id" --keychain-profile "$NOTARY_PROFILE" "$OUT/notary-log-$id.json" || true
    fail "Apple did not accept $(basename "$file"). See $OUT/notary-log-$id.json"
  fi
}

ditto -c -k --keepParent "$APP" "$OUT/Axo-notarize.zip"
notarize "$OUT/Axo-notarize.zip"
xcrun stapler staple "$APP"
rm "$OUT/Axo-notarize.zip"

say "DMG"
scripts/make-dmg.sh "$APP" "$DMG"
# A signed DMG gets its own ticket. The unsigned DMG of cloud signing does not need one: macOS
# checks the app inside, which has its ticket already. Apple took over 6 hours for the first
# unsigned DMG (2026-10-22), so it is only sent with AXO_NOTARIZE_DMG=1.
if [[ "$SIGNING" == "local" ]]; then codesign --sign "$IDENTITY" --timestamp "$DMG"; fi
if [[ "$SIGNING" == "local" || "${AXO_NOTARIZE_DMG:-0}" == "1" ]]; then
  notarize "$DMG"
  xcrun stapler staple "$DMG"
fi

say "Gatekeeper check"
spctl --assess --type execute --verbose=2 "$APP"
if [[ "$SIGNING" == "local" ]]; then
  spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
fi
dmg_mount="$(mktemp -d)"
hdiutil attach -nobrowse -readonly -quiet -mountpoint "$dmg_mount" "$DMG"
xcrun stapler validate "$dmg_mount/Axo.app"
spctl --assess --type execute --verbose=2 "$dmg_mount/Axo.app"
hdiutil detach -quiet "$dmg_mount"

# ---------------------------------------------------------------- update feed and cask

say "Sparkle appcast"
updates="$OUT/updates"
mkdir -p "$updates"
[[ -f site/appcast.xml ]] && cp site/appcast.xml "$updates/appcast.xml"
cp "$DMG" "$updates/Axo.dmg"
cp "docs/release-notes/$VERSION.md" "$updates/Axo.md"
"$SPARKLE_BIN/generate_appcast" \
  --ed-key-file "$SPARKLE_KEY" \
  --embed-release-notes \
  --download-url-prefix "$REPO_URL/releases/download/v$VERSION/" \
  --link "$SITE_URL" \
  --maximum-deltas 0 \
  --maximum-versions 10 \
  "$updates"
cp "$updates/appcast.xml" site/appcast.xml

say "Homebrew cask"
sha="$(shasum -a 256 "$DMG" | cut -d' ' -f1)"
sed -e "s/{{VERSION}}/$VERSION/g" -e "s/{{SHA256}}/$sha/g" packaging/homebrew/axo.rb.template >"$OUT/axo.rb"

say "Done: Axo $VERSION"
cat <<DONE
  App:      $APP
  DMG:      $DMG  (sha256 $sha)
  Appcast:  site/appcast.xml (changed, commit it)
  Cask:     $OUT/axo.rb
Next: check the DMG on a second Mac, then scripts/publish.sh $VERSION.
DONE
