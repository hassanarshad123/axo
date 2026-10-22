import AppKit
import BuddyCore
import Testing

@testable import NotchUI

/// These tests read the real art in Sources/NotchUI/Resources/Buddies.
/// With the pack codes in AXO_UNLOCK_CODES (`make test` on Hassan's Mac), they check the locked buddies too.
@Suite("BuddySprites")
@MainActor
struct BuddySpritesTests {
    private let sprites: BuddySprites = {
        let sprites = BuddySprites()
        let codes = ProcessInfo.processInfo.environment["AXO_UNLOCK_CODES"] ?? ""
        for code in codes.split(separator: ",").compactMap({ UnlockCode(String($0)) }) {
            sprites.unlock(code)
        }
        return sprites
    }()
    private let axo = BuddyCatalog.defaultBuddyID

    @Test("The catalog ships with the package and has Axo")
    func catalogLoads() {
        #expect(sprites.catalog.buddies.count >= 16)
        #expect(sprites.catalog.buddy(withID: axo)?.name == "Axo")
    }

    @Test("The resource bundle is found by name, without Bundle.module")
    func findsResourceBundle() throws {
        let bundle = try #require(BuddySprites.resourceBundle())
        #expect(bundle.bundleURL.lastPathComponent == BuddySprites.resourceBundleName)
        #expect(bundle.url(forResource: "Buddies", withExtension: nil) != nil)
    }

    /// A wrong main hue, or a limit that is too high, turns nothing: every color choice then looks the same.
    /// (Nubo once turned 2%: its pale mint shading is below the default saturation limit.)
    /// Some buddies turn almost all pixels, because their outlines have the body hue (Sloth, Mochi).
    /// The eyes and the white parts must still stay.
    @Test("Every buddy turns part of its art, not none and not all")
    func everyBuddyTurnsPartOfItsArt() throws {
        for buddy in sprites.catalog.buddies {
            let far = try #require(BuddyColor.choices(for: buddy, keeping: .original).last)
            let original = try #require(SpritePixels(sprites.image(buddyID: buddy.id, color: .original, pose: "happy")))
            let turned = try #require(SpritePixels(sprites.image(buddyID: buddy.id, color: far, pose: "happy")))
            var visible = 0
            var changed = 0
            for y in 0..<original.height {
                for x in 0..<original.width {
                    guard let before = original.color(x: x, y: y), let after = turned.color(x: x, y: y) else {
                        continue
                    }
                    visible += 1
                    if SpritePixels.difference(before, after) > 0.05 { changed += 1 }
                }
            }
            let share = Double(changed) / Double(max(visible, 1))
            #expect(share > 0.03 && share < 0.995, "\(buddy.id): \(Int(share * 100))% of the pixels turned")
        }
    }

    @Test("Every buddy has every core pose, in every color")
    func everyCorePoseLoads() {
        for buddy in sprites.catalog.buddies {
            for pose in BuddyAssets.corePoses {
                #expect(sprites.image(buddyID: buddy.id, color: .original, pose: pose) != nil, "\(buddy.id) \(pose)")
            }
        }
        for color in BuddyColor.allCases {
            #expect(sprites.image(buddyID: axo, color: color, pose: "happy") != nil, "\(color)")
        }
    }

    @Test("Missing art falls back: calm and blink to happy, form art to the plain pose")
    func missingArtFallsBack() {
        #expect(sprites.image(buddyID: axo, color: .original, pose: "calm") != nil)
        #expect(sprites.image(buddyID: axo, color: .original, pose: "worried", form: 4) != nil)
        #expect(sprites.image(buddyID: axo, color: .original, pose: "no-such-pose") == nil)
        #expect(sprites.image(buddyID: "99-gone", color: .original, pose: "happy") == nil)
    }

    @Test("Images are made once and then come from the cache")
    func cached() {
        let first = sprites.image(buddyID: axo, color: .teal, pose: "happy")
        let second = sprites.image(buddyID: axo, color: .teal, pose: "happy")
        #expect(first != nil)
        #expect(first === second)
    }

    /// Axo is the default, with light pinks right at the edge of the hue window.
    /// Hassan has skin far from his blue main color: it must not turn.
    @Test(
        "A color keeps the see-through parts and turns the main color like HueSwap does",
        arguments: ["25-axo-axolotl", "29-hassan-desi"])
    func recolorMatchesHueSwap(buddyID: String) throws {
        let original = try #require(SpritePixels(sprites.image(buddyID: buddyID, color: .original, pose: "happy")))
        let teal = try #require(SpritePixels(sprites.image(buddyID: buddyID, color: .teal, pose: "happy")))
        let buddy = try #require(sprites.catalog.buddy(withID: buddyID))
        let swap = try #require(HueSwap(buddy: buddy, color: .teal))
        #expect(original.width == teal.width)
        #expect(original.height == teal.height)

        var visible = 0
        var close = 0
        var alphaChanged = 0
        for y in 0..<original.height {
            for x in 0..<original.width {
                if abs(original.alpha(x: x, y: y) - teal.alpha(x: x, y: y)) > 0.01 { alphaChanged += 1 }
                guard original.alpha(x: x, y: y) > 0.5, let before = original.color(x: x, y: y),
                    let after = teal.color(x: x, y: y)
                else { continue }
                visible += 1
                if SpritePixels.difference(after, swap.apply(before)) < 0.02 { close += 1 }
            }
        }
        #expect(alphaChanged == 0)
        #expect(visible > 5000)
        #expect(Double(close) / Double(visible) > 0.995, "\(close) of \(visible) pixels match")
    }

    @Test("Missing files, a missing folder and a broken catalog give nil, not a crash")
    func missingArtOnDisk() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "BuddySpritesTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(
            at: folder.appending(path: "a-buddy"), withIntermediateDirectories: true)
        let catalog = #"{"buddies":[{"id":"a-buddy","name":"A","mainHue":10,"assets":["happy"]}]}"#
        try Data(catalog.utf8).write(to: folder.appending(path: "catalog.json"))

        let listedButMissing = BuddySprites(directory: folder)
        #expect(listedButMissing.catalog.buddies.count == 1)
        #expect(listedButMissing.image(buddyID: "a-buddy", color: .teal, pose: "happy") == nil)
        #expect(listedButMissing.menuBarImage(buddyID: "a-buddy", color: .original, style: .color) == nil)

        try Data("not json".utf8).write(to: folder.appending(path: "catalog.json"))
        #expect(BuddySprites(directory: folder).catalog.buddies.isEmpty)
        #expect(BuddySprites(directory: nil).image(buddyID: axo, color: .original, pose: "happy") == nil)
    }

    @Test("Only buddies from the catalog are read, so a saved id cannot point at another folder")
    func unknownIDsReadNothing() {
        #expect(sprites.image(buddyID: "../25-axo-axolotl", color: .original, pose: "happy") == nil)
        #expect(!sprites.hasAsset("happy", buddyID: "../Buddies/25-axo-axolotl"))
    }

    @Test("The color menu bar icon is 18 pt tall, from its own art or the happy pose")
    func colorMenuBarIcon() throws {
        let image = try #require(sprites.menuBarImage(buddyID: axo, color: .original, style: .color))
        #expect(image.size.height == 18)
        #expect(!image.isTemplate)
    }

    @Test("The outline menu bar icon is a template image, or nil so the app uses a symbol")
    func outlineMenuBarIcon() {
        var withArt = 0
        for buddy in sprites.catalog.buddies {
            let image = sprites.menuBarImage(buddyID: buddy.id, color: .violet, style: .outline)
            if sprites.hasAsset("menubar-outline", buddyID: buddy.id) {
                withArt += 1
                #expect(image?.isTemplate == true, "\(buddy.id)")
                #expect(image?.size.height == 18, "\(buddy.id)")
            } else {
                #expect(image == nil, "\(buddy.id)")
            }
        }
        // Goo had outline art first. If this fails, check the export before the code.
        #expect(withArt >= 1)
    }

    @Test("Every buddy has a color menu bar icon, from its head art or its happy pose")
    func everyBuddyHasColorIcon() {
        for buddy in sprites.catalog.buddies {
            let image = sprites.menuBarImage(buddyID: buddy.id, color: .teal, style: .color)
            #expect(image?.size.height == 18, "\(buddy.id)")
            #expect(image?.isTemplate == false, "\(buddy.id)")
        }
    }
}
