import Foundation
import Testing

@testable import BuddyCore

private func buddy(_ id: String) -> Buddy {
    Buddy(id: id, number: 40, name: "X", mainHue: 0)
}

@Suite("Locked buddy pack")
struct BuddyPackTests {
    private let code = UnlockCode("7KQ3-XW9P-2M4T-HB6R")!
    private let otherCode = UnlockCode("7KQ3-XW9P-2M4T-HB6S")!
    /// Stands in for PNG bytes. The pack does not read the images, it only carries them.
    private let art = Data("pixel art of a secret buddy".utf8)

    private var pack: BuddyPack {
        BuddyPack(
            buddies: [Buddy(id: "40-secret-buddy", number: 40, name: "Secret Friend", mainHue: 200, hueTolerance: 20)],
            art: ["40-secret-buddy": ["happy": art, "form1-happy": art]])
    }

    @Test("The right code opens the pack, with every buddy and every image")
    func roundTrip() throws {
        let sealed = try pack.sealed(with: code)
        #expect(try BuddyPack.opened(sealed, with: code) == pack)
    }

    @Test("A wrong code does not open the pack")
    func wrongCode() throws {
        let sealed = try pack.sealed(with: code)
        #expect(throws: BuddyPackError.wrongCode) { try BuddyPack.opened(sealed, with: otherCode) }
    }

    @Test("A changed byte stops the pack from opening, so nobody can slip in other art")
    func tampered() throws {
        var sealed = try pack.sealed(with: code)
        sealed[sealed.count - 20] ^= 0x01
        #expect(throws: BuddyPackError.wrongCode) { try BuddyPack.opened(sealed, with: code) }
    }

    @Test("Other files are not packs", arguments: [Data(), Data("AXOPACK1".utf8), Data(repeating: 7, count: 400)])
    func notAPack(_ data: Data) {
        #expect(throws: BuddyPackError.notAPack) { try BuddyPack.opened(data, with: self.code) }
    }

    @Test("The locked file shows nothing: no image bytes and no buddy name")
    func showsNothing() throws {
        let sealed = try pack.sealed(with: code)
        #expect(sealed.range(of: art) == nil)
        #expect(sealed.range(of: Data("Secret Friend".utf8)) == nil)
        #expect(sealed.range(of: Data("40-secret-buddy".utf8)) == nil)
    }

    @Test("Two lockings of the same pack give different files (new random salt and nonce)")
    func freshEachTime() throws {
        #expect(try pack.sealed(with: code) != pack.sealed(with: code))
    }

    @Test(
        "A pack with an unsafe buddy id, an unsafe image name or art for an unlisted buddy is refused",
        arguments: [
            BuddyPack(buddies: [buddy("../40-x")], art: ["../40-x": ["happy": Data([1])]]),
            BuddyPack(buddies: [buddy("40-x")], art: ["40-x": ["../happy": Data([1])]]),
            BuddyPack(buddies: [buddy("40-x")], art: ["41-y": ["happy": Data([1])]]),
            BuddyPack(buddies: [buddy("40-x")], art: [:]),
            BuddyPack(buddies: [buddy("40-x"), buddy("40-x")], art: ["40-x": ["happy": Data([1])]]),
            BuddyPack(buddies: [], art: [:]),
        ])
    func unsafeContents(_ bad: BuddyPack) {
        #expect(throws: BuddyPackError.damaged) { try bad.sealed(with: self.code) }
    }

    @Test("Buddy ids and image names use only small letters, digits and dashes")
    func safeNames() {
        #expect(BuddyPack.isSafeName("30-two-friends"))
        #expect(BuddyPack.isSafeName("form3-neck-left"))
        #expect(!BuddyPack.isSafeName(""))
        #expect(!BuddyPack.isSafeName("a/b"))
        #expect(!BuddyPack.isSafeName(".."))
        #expect(!BuddyPack.isSafeName("Happy"))
    }
}
