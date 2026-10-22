# Release (milestone 8)

Everything runs on this Mac. Apple signs and checks the app in the cloud, so no certificate file and no API key are needed (DECISIONS T56).

```
 scripts/release.sh 1.0.0                                 (on this Mac, nothing goes public)
   tests ─▶ Release archive ─▶ export: Xcode signs with the team's Developer ID at Apple
         ─▶ notarize (Apple) ─▶ staple ─▶ DMG (sign + notarize: local signing only) ─▶ Gatekeeper check
         ─▶ site/appcast.xml (Sparkle feed, EdDSA signed) ─▶ build/release/axo.rb (cask)

 scripts/publish.sh --yes 1.0.0                           (public, needs docs/launch/APPROVALS.md)
   public copy (no private folders) ─▶ repo "axo" ─▶ GitHub release (Axo.dmg) ─▶ Homebrew tap
   ─▶ axo.zensbot.com ─▶ URL checks
```

## Status

| Item | Where | Status |
|---|---|---|
| Sparkle EdDSA key pair | Private: login Keychain (account "axo") + `~/.secrets/pem/sparkle-axo-eddsa.key`. Public: `project.yml` | ✅ 2026-10-22 |
| Update check and usage counts in the app | `AppUpdater`, `UsageCounts` | ✅ |
| Release, DMG and publish scripts | `scripts/release.sh`, `scripts/make-dmg.sh`, `scripts/publish.sh` | ✅ |
| Developer ID signature | Cloud signing in Xcode (team 5PDR77PRWF, Zensbot LLC) | ✅ 2026-10-22, tested |
| Notarization | Keychain profile `axo-notary` | ✅ Axo 1.0.0 accepted by Apple (2026-10-22) |
| TelemetryDeck app id | "TelemetryDeck app id" below | ⬜ Optional. Without it, the app sends no counts |
| Approvals before publish | `docs/launch/APPROVALS.md` | See the file |

## Signing: cloud Developer ID (done 2026-10-22)

`release.sh` looks for a "Developer ID Application" certificate in the Keychain. There is none, so it uses cloud signing:

1. The archive is signed with the "Apple Development" certificate of this Mac.
2. `xcodebuild -exportArchive -allowProvisioningUpdates` with `signingStyle automatic`. Xcode asks Apple to sign with the team's cloud Developer ID certificate. The result says "Developer ID Application: Zensbot LLC (5PDR77PRWF)".
3. This needs the Apple ID in **Xcode > Settings > Accounts**, with the Admin or Account Holder role in the Zensbot LLC team.

The DMG is not signed (only a local certificate can sign it), and it is not notarized. macOS checks the app inside it, and that app is signed, notarized and stapled. Apple took more than 6 hours for the first unsigned DMG (2026-10-22), so `release.sh` sends the DMG only with `AXO_NOTARIZE_DMG=1`.

If a local certificate is made later (Xcode > Settings > Accounts > Manage Certificates > + > Developer ID Application), `release.sh` uses it and also signs the DMG.

## Notarization: the `axo-notary` profile (done 2026-10-22)

The Apple ID and an app-specific password from `~/.secrets` (`apple-appstoreconnect`) are saved in the Keychain:

```sh
xcrun notarytool store-credentials axo-notary --apple-id <id> --team-id 5PDR77PRWF --validate
```

The password goes in on stdin, never on the command line. If Apple refuses it later, make a new app-specific password at https://account.apple.com, save it in `~/.secrets`, and run the command again.

## TelemetryDeck app id (optional, Hassan, about 3 minutes)

1. Open https://dashboard.telemetrydeck.com and sign up with a Zensbot email. Use the free plan.
2. Make a new app named `Axo`.
3. Copy the **App ID** (it looks like `A1B2C3D4-…`).
4. Give it to Claude. Claude saves it in `~/.secrets` (component `axo`, key `TELEMETRYDECK_APP_ID`). It is not a secret: it ships inside the app.
5. Claude sends one count from a Debug build and checks that it shows in TelemetryDeck's **Test Mode**. Axo sends counts with its own code (`UsageReport`, DECISIONS T51), so this proves that TelemetryDeck accepts them.

## Each release (Claude)

1. Set `MARKETING_VERSION` in `project.yml`. Write `docs/release-notes/<version>.md`. Commit.
2. Run `scripts/release.sh --check <version>`. Fix what it lists.
3. Run `scripts/release.sh <version>`. Apple checks the app and the DMG. Each check takes minutes, sometimes hours.
4. Commit `site/appcast.xml`.
5. Open `build/release/Axo.dmg` on a second Mac. It must open with no warning.
6. Run `scripts/publish.sh --check <version>`. When every box in `docs/launch/APPROVALS.md` is ticked, run `scripts/publish.sh --yes <version>`.

The build number is the git commit count, so each release is higher than the last one.

## Sparkle key

- Sparkle installs an update only when the EdDSA key signed it. The public half is in the app.
- **Warning:** Do not lose the private key. If it is lost, no installed copy of Axo can update again. Users must download the app again by hand.
- Backup off this Mac: Apple Passwords, entry "Axo Sparkle key" (Hassan's choice, 2026-10-22). To restore it, save the text as a file and use the next line.
- To use it on a new Mac: `generate_keys --account axo -f <key file>` (Sparkle's tool in `build/SourcePackages/artifacts/sparkle/Sparkle/bin/`).

## Rules

- Never commit certificates, `.p12` or `.p8` files, API keys or the Sparkle private key. `.gitignore` blocks the common ones.
- Release builds use the hardened runtime and the camera entitlement. `release.sh` stops if either one is missing.
- This repo stays private. `publish.sh` puts a fresh copy of each release in the public repo, without the paths in `scripts/private-paths.txt`, as Hassan with his GitHub private address (DECISIONS T55). It stops if the copy holds a word from `private/guard-words.txt`, a photo or a secret.
