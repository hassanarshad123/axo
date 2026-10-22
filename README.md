# Axo

A calm, cute buddy that lives in your MacBook notch. It watches your posture, reminds you to stand up, stretch, rest your eyes and drink water, and grows as you look after yourself.

The default buddy is Axo, the pink axolotl. You can pick one of 16 buddies, rename it and change its color. Secret buddies open with a code.

Free. Private by design: camera pictures are checked on your Mac and never sent. The only network calls are a daily update check and anonymous usage counts, and you can turn both off.
Made by Hassan Arshad.

> Status: **version 1.0.** See [docs/ROADMAP.md](docs/ROADMAP.md).

## Run it

Needs macOS 14+, Xcode 16+ and XcodeGen (`brew install xcodegen`).

```sh
make test   # unit tests for the shared code
make run    # make the Xcode project, build, open the app
make install  # Release build in /Applications, signed with your Apple Development certificate
```

To work in Xcode: `make project`, then open `Axo.xcodeproj`.
The app has no Dock icon. Look for it in the menu bar and in the notch.

## Docs

| File | What it holds |
|---|---|
| [docs/PRODUCT.md](docs/PRODUCT.md) | What the app does and for whom |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Every product and tech decision, with dates |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Tech stack, folders, how the parts talk |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Build order and status |
| [docs/CHARACTER.md](docs/CHARACTER.md) | The buddy character: options, pick, asset list |
| [docs/PRIVACY.md](docs/PRIVACY.md) | Privacy rules the code must follow |
| [docs/RELEASE.md](docs/RELEASE.md) | Signing, notarization, DMG, Homebrew plan |
| [CLAUDE.md](CLAUDE.md) | Rules for AI coding agents in this repo |

The art sources (`design/`) and the launch texts are not in the public repo. The finished art is in the app folders.

## License

The code is MIT licensed (`LICENSE`). The art, the voice recordings, the Axo name and the buddies that show real people are all rights reserved (`ASSETS-LICENSE.md`).
