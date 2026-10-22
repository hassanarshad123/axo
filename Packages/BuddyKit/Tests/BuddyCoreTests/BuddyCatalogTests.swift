import Foundation
import Testing

@testable import BuddyCore

@Suite("BuddyCatalog")
struct BuddyCatalogTests {
    private let json = """
        {"buddies":[
          {"id":"09-goo-slime","number":9,"name":"Goo","mainHue":175},
          {"id":"25-axo-axolotl","number":25,"name":"Axo","mainHue":345,"assets":["happy"],"futureKey":true},
          {"id":"29-hassan-desi","name":"Hassan","mainHue":345,"hueTolerance":20},
          {"id":"10-neko-cat","name":"Neko","mainHue":35,"hueCenter":38,"minSaturation":0.5,"minValue":0.65}
        ]}
        """

    private func catalog() throws -> BuddyCatalog {
        try BuddyCatalog.decoded(from: Data(json.utf8))
    }

    @Test func readsTheCatalogFile() throws {
        let catalog = try catalog()
        #expect(catalog.buddies.map(\.id) == ["09-goo-slime", "25-axo-axolotl", "29-hassan-desi", "10-neko-cat"])
        let goo = try #require(catalog.buddy(withID: "09-goo-slime"))
        #expect(goo.name == "Goo")
        #expect(goo.number == 9)
        #expect(goo.mainHue == 175)
    }

    @Test("Missing optional fields get defaults; unknown keys (an old \"assets\" list) are ignored")
    func optionalFields() throws {
        let hassan = try #require(try catalog().buddy(withID: "29-hassan-desi"))
        #expect(hassan.number == 0)
        #expect(hassan.hueTolerance == 20)
        #expect(hassan.hueCenter == 345)
        #expect(hassan.minSaturation == HueSwap.defaultMinimumSaturation)
        #expect(hassan.minValue == 0)
        let axo = try #require(try catalog().buddy(withID: "25-axo-axolotl"))
        #expect(axo.hueTolerance == HueSwap.defaultTolerance)
    }

    @Test("The color window fields are read when present")
    func colorWindowFields() throws {
        let neko = try #require(try catalog().buddy(withID: "10-neko-cat"))
        #expect(neko.mainHue == 35)
        #expect(neko.hueCenter == 38)
        #expect(neko.minSaturation == 0.5)
        #expect(neko.minValue == 0.65)
        let swap = try #require(HueSwap(buddy: neko, color: .sky))
        #expect(swap.sourceHue == 35)
        #expect(swap.centerHue == 38)
        #expect(swap.minimumSaturation == 0.5)
        #expect(swap.minimumValue == 0.65)
    }

    @Test("A broken buddy entry is skipped, the others stay")
    func brokenEntryIsSkipped() throws {
        let json = #"{"buddies":[{"id":"x","name":"No hue"},{"id":"25-axo-axolotl","name":"Axo","mainHue":345}]}"#
        let catalog = try BuddyCatalog.decoded(from: Data(json.utf8))
        #expect(catalog.buddies.map(\.id) == ["25-axo-axolotl"])
    }

    @Test("An unknown buddy id falls back to Axo")
    func unknownIDFallsBackToAxo() throws {
        let catalog = try catalog()
        #expect(catalog.resolvedBuddy(id: "99-gone")?.id == BuddyCatalog.defaultBuddyID)
        #expect(catalog.resolvedBuddy(id: nil)?.id == BuddyCatalog.defaultBuddyID)
        #expect(catalog.resolvedBuddy(id: "09-goo-slime")?.id == "09-goo-slime")
    }

    @Test("Without Axo, the first buddy is the fallback; an empty catalog has none")
    func fallbackWithoutAxo() throws {
        let goo = try #require(try catalog().buddy(withID: "09-goo-slime"))
        #expect(BuddyCatalog(buddies: [goo]).resolvedBuddy(id: "99-gone") == goo)
        #expect(BuddyCatalog(buddies: []).resolvedBuddy(id: "99-gone") == nil)
    }

    @Test("Bad JSON throws")
    func badJSONThrows() {
        #expect(throws: (any Error).self) { try BuddyCatalog.decoded(from: Data("nope".utf8)) }
    }
}
