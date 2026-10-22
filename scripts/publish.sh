#!/usr/bin/env bash
# Publishes an Axo release that scripts/release.sh made. Outward and hard to undo, so it runs
# only when every box in docs/launch/APPROVALS.md is ticked. See docs/RELEASE.md.
#
#   scripts/publish.sh --check 1.0.0    read only: make the public copy, list what is not ready
#   scripts/publish.sh --yes 1.0.0      publish
#
#   checks ─▶ public copy (HEAD minus scripts/private-paths.txt) ─▶ guards (words, photos, secrets)
#          ─▶ public repo "axo": one commit + tag ─▶ GitHub release (DMG) ─▶ Homebrew tap
#          ─▶ website on Cloudflare Pages (axo.zensbot.com) ─▶ check every URL
#
# This repo stays private. The public repo gets a fresh copy of each release, with no old
# history (docs/DECISIONS.md T55). Each step looks first and skips work that is already done,
# so a second run is safe.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OWNER="hassanarshad123"
REPO="axo"
TAP="homebrew-axo"
DOMAIN="axo.zensbot.com"
ZONE="zensbot.com"
PAGES_PROJECT="axo"
CF_ACCOUNT_ID="1f52e875e3d0bacd2df59040824ee5bf" # the Zensbot Cloudflare account (not a secret)
PRIVATE_EMAIL="196851987+hassanarshad123@users.noreply.github.com"
OUT="build/release"
SNAPSHOT="$OUT/public"
GUARD_WORDS="private/guard-words.txt"

say() { printf '\n==> %s\n' "$*"; }
fail() {
  printf '\nSTOP: %s\n' "$*" >&2
  exit 1
}

MODE="${1:-}"
case "$MODE" in
  --check | --yes) VERSION="${2:-}" ;;
  *) fail "Use --check <version> or --yes <version>." ;;
esac
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Give the version, for example: scripts/publish.sh --check 1.0.0"
TAG="v$VERSION"

# ---------------------------------------------------------------- public copy

is_kept() { # is_kept <path>: true when a "!" line of private-paths.txt keeps this path.
  local kept
  for kept in ${KEEP[@]+"${KEEP[@]}"}; do
    [[ "$1" == "$kept" ]] && return 0
  done
  return 1
}

make_snapshot() { # The committed files of HEAD, without the private paths.
  local line pattern path
  REMOVE=() KEEP=()
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ "$line" == !* ]]; then KEEP+=("${line#!}"); else REMOVE+=("$line"); fi
  done <scripts/private-paths.txt
  rm -rf "$SNAPSHOT"
  mkdir -p "$SNAPSHOT"
  git archive HEAD | tar -x -C "$SNAPSHOT"
  shopt -s nullglob
  for pattern in ${REMOVE[@]+"${REMOVE[@]}"}; do
    # shellcheck disable=SC2206 # the glob must expand here
    local paths=("$SNAPSHOT"/$pattern)
    for path in ${paths[@]+"${paths[@]}"}; do
      is_kept "${path#"$SNAPSHOT"/}" || rm -rf "$path"
    done
  done
  shopt -u nullglob
}

# ---------------------------------------------------------------- checks

missing=()
need() { missing+=("$1"); }

if grep -q -- '- \[ \]' docs/launch/APPROVALS.md; then
  need "docs/launch/APPROVALS.md has boxes that are not ticked."
fi
if grep -q "DRAFT" docs/PRIVACY-NOTICE.md site/privacy.html ASSETS-LICENSE.md; then
  need "A public text still says DRAFT (the privacy notice or ASSETS-LICENSE.md)."
fi

check_dmg() { # The app in the DMG has Apple's ticket and passes Gatekeeper.
  local mount
  mount="$(mktemp -d)"
  if ! hdiutil attach -nobrowse -readonly -quiet -mountpoint "$mount" "$OUT/Axo.dmg"; then
    need "$OUT/Axo.dmg does not open."
    return
  fi
  xcrun stapler validate -q "$mount/Axo.app" 2>/dev/null || need "The app in the DMG has no notarization ticket."
  spctl --assess --type execute "$mount/Axo.app" 2>/dev/null || need "Gatekeeper refuses the app in the DMG."
  hdiutil detach -quiet "$mount" || true
}
if [[ -f "$OUT/Axo.dmg" ]]; then check_dmg; else need "No $OUT/Axo.dmg. Run scripts/release.sh $VERSION first."; fi
grep -q "version \"$VERSION\"" "$OUT/axo.rb" 2>/dev/null || need "$OUT/axo.rb is missing or not for $VERSION."
grep -q "<sparkle:shortVersionString>$VERSION<" site/appcast.xml 2>/dev/null ||
  need "site/appcast.xml has no $VERSION item. Run scripts/release.sh $VERSION."
[[ -f "docs/release-notes/$VERSION.md" ]] || need "No docs/release-notes/$VERSION.md."

[[ "$(git branch --show-current)" == "main" ]] || need "Publish from the main branch."
[[ -z "$(git status --porcelain)" ]] ||
  need "The git tree has changed or new files that are not committed (site/appcast.xml?)."

make_snapshot
if [[ -s "$GUARD_WORDS" ]]; then
  words="$(grep -v '^#' "$GUARD_WORDS" | sed '/^[[:space:]]*$/d')"
  if grep -r -i -I -l -F -e "$words" "$SNAPSHOT" >/dev/null; then
    need "The public copy holds a private word. Find it with grep -r -i -I -l in $SNAPSHOT."
  fi
  while IFS= read -r word; do
    [[ -z "$(find "$SNAPSHOT" -iname "*$word*" | head -1)" ]] ||
      need "A file name in the public copy holds a private word ($SNAPSHOT)."
  done <<<"$words"
else
  need "$GUARD_WORDS is missing. Only the private repo can publish."
fi
if find "$SNAPSHOT" -type f | grep -qiE '\.(jpe?g|heic|heif|dng|tiff?|mov|mp4)$'; then
  need "The public copy holds a photo or video file. Real people's photos must never go public."
fi
if gitleaks dir --redact --no-banner --log-level error --exit-code 1 "$SNAPSHOT" >/dev/null 2>&1; then :; else
  need "gitleaks found a possible secret in the public copy. Run: gitleaks dir --redact -v $SNAPSHOT"
fi

for tool in gh gitleaks wrangler brew curl rsync; do
  command -v "$tool" >/dev/null || need "The tool '$tool' is not installed."
done
gh auth status >/dev/null 2>&1 || need "gh is not signed in."

CF_TOKEN="$(sed -n 's/^CLOUDFLARE_ADMIN_TOKEN=//p' "$HOME/.secrets/env/shared.env" 2>/dev/null | tr -d '"' | head -1)"
[[ -n "$CF_TOKEN" ]] || need "CLOUDFLARE_ADMIN_TOKEN is not in ~/.secrets/env/shared.env."

if ((${#missing[@]})); then
  printf '\nNot ready to publish. Fix these first:\n' >&2
  printf '  - %s\n' "${missing[@]}" >&2
  exit 1
fi
say "Ready to publish Axo $VERSION ($(find "$SNAPSHOT" -type f | wc -l | tr -d ' ') files in the public copy)"
[[ "$MODE" == "--check" ]] && exit 0

# ---------------------------------------------------------------- publish

cf() { # cf <method> <path> [json]: one Cloudflare API call; prints the JSON answer.
  # The token goes in on stdin, so it never shows in the process list (ps) for other programs.
  local args=(-sS -X "$1" "https://api.cloudflare.com/client/v4$2" -H @- -H "Content-Type: application/json")
  if [[ -n "${3:-}" ]]; then args+=(--data "$3"); fi
  curl "${args[@]}" <<<"Authorization: Bearer $CF_TOKEN"
}
cf_success() { # cf_success: reads a Cloudflare answer on stdin; true when it says "success": true.
  [[ "$(plutil -extract success raw - 2>/dev/null)" == "true" ]]
}
cf_ok() { # cf_ok <method> <path> <json>: like cf, but stops when Cloudflare refuses.
  local answer
  answer="$(cf "$@")"
  cf_success <<<"$answer" || fail "Cloudflare refused $1 $2: $(head -c 400 <<<"$answer")"
}
# Cloudflare answers with spaces in its JSON ("name": "x"), so match the name with a pattern.
has_name() { grep -Eq "\"name\": *\"$1\""; }
as_hassan() { git -c user.name="Hassan Arshad" -c user.email="$PRIVATE_EMAIL" "$@"; }

say "Public repo $OWNER/$REPO"
if ! gh repo view "$OWNER/$REPO" >/dev/null 2>&1; then
  gh repo create "$OWNER/$REPO" --public --homepage "https://$DOMAIN" \
    --description "A calm buddy in your MacBook notch for posture and breaks. Free and private."
fi
public_dir="$OUT/public-repo"
rm -rf "$public_dir"
gh repo clone "$OWNER/$REPO" "$public_dir" -- --quiet 2>/dev/null
git -C "$public_dir" checkout -q -B main
rsync -a --delete --exclude .git "$SNAPSHOT/" "$public_dir/"
git -C "$public_dir" add -A
if ! git -C "$public_dir" diff --cached --quiet; then
  as_hassan -C "$public_dir" commit -q -m "Axo $VERSION"
fi
if ! git -C "$public_dir" rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  as_hassan -C "$public_dir" tag -a "$TAG" -m "Axo $VERSION"
fi
git -C "$public_dir" push -q origin main "$TAG"
if [[ "$(gh repo view "$OWNER/$REPO" --json visibility --jq .visibility)" != "PUBLIC" ]]; then
  gh repo edit "$OWNER/$REPO" --visibility public --accept-visibility-change-consequences
fi

say "GitHub release $TAG"
if ! gh release view "$TAG" --repo "$OWNER/$REPO" >/dev/null 2>&1; then
  gh release create "$TAG" "$OUT/Axo.dmg" --repo "$OWNER/$REPO" --verify-tag \
    --title "Axo $VERSION" --notes-file "docs/release-notes/$VERSION.md"
else
  # A second release.sh run makes a new DMG, and the feed and the cask hold its signature and
  # checksum. The DMG on GitHub must be that same file, or updates and brew installs fail.
  local_sha="$(shasum -a 256 "$OUT/Axo.dmg" | cut -d' ' -f1)"
  remote_sha="$(gh release download "$TAG" --repo "$OWNER/$REPO" -p Axo.dmg -O - 2>/dev/null |
    shasum -a 256 | cut -d' ' -f1)"
  if [[ "$local_sha" != "$remote_sha" ]]; then
    echo "  The DMG on GitHub is not $OUT/Axo.dmg. Replace it."
    gh release upload "$TAG" "$OUT/Axo.dmg" --repo "$OWNER/$REPO" --clobber
  fi
fi

say "Homebrew tap $OWNER/$TAP"
if ! gh repo view "$OWNER/$TAP" >/dev/null 2>&1; then
  gh repo create "$OWNER/$TAP" --public --description "Homebrew tap for Axo (https://$DOMAIN)"
fi
tap_dir="$OUT/tap"
rm -rf "$tap_dir"
gh repo clone "$OWNER/$TAP" "$tap_dir" -- --quiet 2>/dev/null
git -C "$tap_dir" checkout -q -B main
mkdir -p "$tap_dir/Casks"
cp "$OUT/axo.rb" "$tap_dir/Casks/axo.rb"
# shellcheck disable=SC2016 # the backticks are Markdown, not a command
printf '# Axo for Homebrew\n\n```sh\nbrew install --cask %s/axo/axo\n```\n\nAxo: https://%s\n' \
  "$OWNER" "$DOMAIN" >"$tap_dir/README.md"
git -C "$tap_dir" add -A
if ! git -C "$tap_dir" diff --cached --quiet; then
  as_hassan -C "$tap_dir" commit -q -m "axo $VERSION"
  git -C "$tap_dir" push -q origin main
fi

say "Website on Cloudflare Pages"
export CLOUDFLARE_API_TOKEN="$CF_TOKEN" CLOUDFLARE_ACCOUNT_ID="$CF_ACCOUNT_ID"
cf GET "/accounts/$CF_ACCOUNT_ID/pages/projects/$PAGES_PROJECT" | cf_success ||
  wrangler pages project create "$PAGES_PROJECT" --production-branch main
wrangler pages deploy site --project-name "$PAGES_PROJECT" --branch main --commit-dirty=true
cf GET "/accounts/$CF_ACCOUNT_ID/pages/projects/$PAGES_PROJECT/domains" | has_name "$DOMAIN" ||
  cf_ok POST "/accounts/$CF_ACCOUNT_ID/pages/projects/$PAGES_PROJECT/domains" "{\"name\":\"$DOMAIN\"}"
zone_id="$(cf GET "/zones?name=$ZONE" | plutil -extract result.0.id raw -)"
cf GET "/zones/$zone_id/dns_records?name=$DOMAIN" | has_name "$DOMAIN" ||
  cf_ok POST "/zones/$zone_id/dns_records" \
    "{\"type\":\"CNAME\",\"name\":\"$DOMAIN\",\"content\":\"$PAGES_PROJECT.pages.dev\",\"proxied\":true}"

say "Check the live URLs (a new domain can take a few minutes)"
check_url() { # check_url <url> [text the body must hold]
  local url="$1" want="${2:-}" tries=0
  until body="$(curl -fsSL --max-time 20 "$url" 2>/dev/null)" && [[ -z "$want" || "$body" == *"$want"* ]]; do
    ((++tries >= 20)) && fail "$url does not answer as expected."
    sleep 30
  done
  echo "  OK  $url"
}
check_file() { # check_file <url>: the file can be downloaded (headers only, redirects followed).
  local url="$1" tries=0
  until curl -fsSIL --max-time 60 "$url" >/dev/null 2>&1; do
    ((++tries >= 10)) && fail "$url cannot be downloaded."
    sleep 30
  done
  echo "  OK  $url"
}
check_url "https://$DOMAIN/" "Axo"
check_url "https://$DOMAIN/privacy" "TelemetryDeck"
check_url "https://$DOMAIN/appcast.xml" "<sparkle:shortVersionString>$VERSION<"
check_url "https://github.com/$OWNER/$REPO"
check_file "https://github.com/$OWNER/$REPO/releases/download/$TAG/Axo.dmg"
check_file "https://github.com/$OWNER/$REPO/releases/latest/download/Axo.dmg" # the website's Download link

say "Homebrew audit"
brew tap "$OWNER/axo"
git -C "$(brew --repository "$OWNER/axo")" pull -q # an older tap copy must see the new cask
brew audit --cask --strict --online "$OWNER/axo/axo"

say "Published Axo $VERSION"
echo "Next: post the launch texts in docs/launch/ (Hassan posts them)."
