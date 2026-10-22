import AppKit
import BuddyCore
import Testing

@testable import NotchUI

/// Locked buddy packs (`BuddyPack`): a code adds their buddies, a wrong code adds nothing.
@Suite("BuddySprites unlock")
@MainActor
struct BuddySpritesUnlockTests {
    private let code = UnlockCode("7KQ3-XW9P-2M4T-HB6R")!
    private let wrongCode = UnlockCode("7KQ3-XW9P-2M4T-HB6S")!
    private let secret = Buddy(id: "40-secret-buddy", number: 40, name: "Secret", mainHue: 200)
    private let openDirectory = BuddySprites.resourceBundle()?.url(forResource: "Buddies", withExtension: nil)

    /// A new folder with one locked pack in it.
    private func packsFolder(_ pack: BuddyPack) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "axo-packs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try pack.sealed(with: code).write(to: folder.appending(path: "pack-01.axopack"))
        return folder
    }

    /// A 2 × 2 blue PNG.
    private func png() throws -> Data {
        let bitmap = try #require(
            NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: 2, pixelsHigh: 2, bitsPerSample: 8, samplesPerPixel: 4,
                hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        for x in 0..<2 {
            for y in 0..<2 { bitmap.setColor(.blue, atX: x, y: y) }
        }
        return try #require(bitmap.representation(using: .png, properties: [:]))
    }

    private func sprites(with pack: BuddyPack) throws -> BuddySprites {
        BuddySprites(directory: openDirectory, packsDirectory: try packsFolder(pack))
    }

    private func secretPack() throws -> BuddyPack {
        BuddyPack(buddies: [secret], art: [secret.id: ["happy": try png()]])
    }

    @Test("The right code adds the locked buddy and its art")
    func rightCode() throws {
        let sprites = try sprites(with: secretPack())
        let before = sprites.catalog.buddies.count
        #expect(sprites.unlock(code) == [secret])
        #expect(sprites.catalog.buddies.count == before + 1)
        #expect(sprites.catalog.buddies.last == secret)
        #expect(sprites.image(buddyID: secret.id, color: .original, pose: "happy")?.size == NSSize(width: 2, height: 2))
        #expect(sprites.image(buddyID: secret.id, color: .teal, pose: "calm") != nil)  // falls back to happy
    }

    @Test("Open buddy ids leave out the unlocked ones")
    func openIDs() throws {
        let sprites = try sprites(with: secretPack())
        let before = sprites.openBuddyIDs
        #expect(before.contains(BuddyCatalog.defaultBuddyID))
        sprites.unlock(code)
        #expect(sprites.catalog.buddy(withID: secret.id) != nil)
        #expect(sprites.openBuddyIDs == before)
    }

    @Test("A wrong code adds nothing")
    func wrongCodeAddsNothing() throws {
        let sprites = try sprites(with: secretPack())
        let before = sprites.catalog
        #expect(sprites.unlock(wrongCode).isEmpty)
        #expect(sprites.catalog == before)
        #expect(sprites.image(buddyID: secret.id, color: .original, pose: "happy") == nil)
    }

    @Test("A locked buddy that was asked for before the unlock shows after it")
    func askedBeforeUnlock() throws {
        let sprites = try sprites(with: secretPack())
        #expect(sprites.image(buddyID: secret.id, color: .original, pose: "happy") == nil)
        sprites.unlock(code)
        #expect(sprites.image(buddyID: secret.id, color: .original, pose: "happy") != nil)
    }

    @Test("The same code twice adds each buddy once")
    func unlockTwice() throws {
        let sprites = try sprites(with: secretPack())
        sprites.unlock(code)
        let once = sprites.catalog
        #expect(sprites.unlock(code) == [secret])
        #expect(sprites.catalog == once)
    }

    @Test("A locked buddy never replaces a buddy that ships open")
    func openBuddyWins() throws {
        let fake = Buddy(id: BuddyCatalog.defaultBuddyID, number: 25, name: "Fake", mainHue: 0)
        let sprites = try sprites(with: BuddyPack(buddies: [fake], art: [fake.id: ["happy": try png()]]))
        sprites.unlock(code)
        #expect(sprites.catalog.buddy(withID: BuddyCatalog.defaultBuddyID)?.name == "Axo")
        #expect(sprites.image(buddyID: BuddyCatalog.defaultBuddyID, color: .original, pose: "happy")?.size.width != 2)
    }

    @Test("With no packs folder, a code opens nothing")
    func noPacksFolder() {
        let sprites = BuddySprites(directory: openDirectory, packsDirectory: nil)
        #expect(sprites.unlock(code).isEmpty)
    }
}
