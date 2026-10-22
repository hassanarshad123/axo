import Testing

@testable import BuddyCore

@Suite("BuddyAppearance")
struct BuddyAppearanceTests {
    private let catalog = BuddyCatalog(buddies: [
        Buddy(id: "10-neko-cat", number: 10, name: "Neko", mainHue: 35),
        Buddy(id: "25-axo-axolotl", number: 25, name: "Axo", mainHue: 345),
    ])

    @Test("Names are cut to 16 characters; an empty name means the buddy's own name")
    func nameLimit() {
        #expect(BuddyName.limited("Mr Pickles the Third") == "Mr Pickles the T")
        #expect(BuddyName.limited("") == nil)
        #expect(BuddyName.limited("   ") == nil)
        #expect(BuddyName.limited(nil) == nil)
        #expect(BuddyName.limited("Pip ") == "Pip ")  // kept while the user types
        #expect(BuddyName.limited("👩‍💻👩‍💻👩‍💻👩‍💻👩‍💻👩‍💻👩‍💻👩‍💻👩‍💻👩‍💻👩‍💻👩‍💻👩‍💻👩‍💻👩‍💻👩‍💻👩‍💻")?.count == 16)
    }

    @Test("The shown name is trimmed, or the buddy's own name")
    func displayName() {
        #expect(BuddyName.display(custom: "  Pip ", default: "Axo") == "Pip")
        #expect(BuddyName.display(custom: nil, default: "Axo") == "Axo")
        #expect(BuddyName.display(custom: " ", default: "Axo") == "Axo")
    }

    @Test("Each buddy keeps its own name: a new name changes only that buddy")
    func namePerBuddy() {
        let names = ["25-axo-axolotl": "Bubbles"]
        let withNeko = BuddyName.names(names, setting: "Kitty", for: "10-neko-cat")
        #expect(withNeko == ["25-axo-axolotl": "Bubbles", "10-neko-cat": "Kitty"])
        #expect(names == ["25-axo-axolotl": "Bubbles"])  // a new value; the old one is not changed

        #expect(BuddyName.names(withNeko, setting: "  ", for: "10-neko-cat") == names)
        #expect(BuddyName.names(withNeko, setting: nil, for: "25-axo-axolotl") == ["10-neko-cat": "Kitty"])
        let long = BuddyName.names([:], setting: "Mr Pickles the Third", for: "10-neko-cat")
        #expect(long == ["10-neko-cat": "Mr Pickles the T"])
    }

    @Test("The shown name is the picked buddy's own saved name")
    func resolveUsesThatBuddysName() {
        let names = ["25-axo-axolotl": "Bubbles"]
        let neko = BuddyAppearance.resolve(buddyID: "10-neko-cat", names: names, color: .original, catalog: catalog)
        #expect(neko.name == "Neko")
        let axo = BuddyAppearance.resolve(buddyID: "25-axo-axolotl", names: names, color: .original, catalog: catalog)
        #expect(axo.name == "Bubbles")
        // An unknown id shows Axo, with the name saved for Axo.
        let unknown = BuddyAppearance.resolve(buddyID: "99-gone", names: names, color: .original, catalog: catalog)
        #expect(unknown == BuddyAppearance(buddyID: "25-axo-axolotl", name: "Bubbles", color: .original))
    }

    @Test("A color that looks like the buddy's own color is not offered, unless it is the saved one")
    func colorChoices() {
        let axo = Buddy(id: "25-axo-axolotl", number: 25, name: "Axo", mainHue: 345)
        #expect(!BuddyColor.choices(for: axo, keeping: .original).contains(.rose))  // 330 is 15 from 345
        #expect(BuddyColor.choices(for: axo, keeping: .original).contains(.violet))
        #expect(BuddyColor.choices(for: axo, keeping: .rose).contains(.rose))
        #expect(BuddyColor.choices(for: axo, keeping: .rose).first == .original)
        let neko = Buddy(id: "10-neko-cat", number: 10, name: "Neko", mainHue: 35)
        #expect(BuddyColor.choices(for: neko, keeping: .original) == [.original, .rose, .lime, .teal, .sky, .violet])
    }

    @Test("Settings turn into what the island shows")
    func resolvesSettings() {
        let names = ["10-neko-cat": "Kitty"]
        let neko = BuddyAppearance.resolve(buddyID: "10-neko-cat", names: names, color: .sky, catalog: catalog)
        #expect(neko == BuddyAppearance(buddyID: "10-neko-cat", name: "Kitty", color: .sky))

        let plain = BuddyAppearance.resolve(buddyID: "10-neko-cat", names: [:], color: .original, catalog: catalog)
        #expect(plain.name == "Neko")
        #expect(plain.form == BuddyAssets.plainForm)
    }

    @Test("The level's form passes through; a form out of range shows the plain art")
    func form() {
        let baby = BuddyAppearance.resolve(
            buddyID: "10-neko-cat", names: [:], color: .original, catalog: catalog, form: 1)
        #expect(baby.form == 1)
        #expect(baby != BuddyAppearance(buddyID: "10-neko-cat", name: "Neko", color: .original))
        #expect(BuddyAppearance(buddyID: "10-neko-cat", name: "Neko", color: .original, form: 9).form == 2)
    }

    @Test("A buddy that left the catalog becomes Axo, with Axo's name")
    func unknownBuddyBecomesAxo() {
        let gone = BuddyAppearance.resolve(buddyID: "99-gone", names: [:], color: .teal, catalog: catalog)
        #expect(gone == BuddyAppearance(buddyID: "25-axo-axolotl", name: "Axo", color: .teal))
    }

    @Test("An empty catalog still gives Axo, without the other buddy's name")
    func emptyCatalog() {
        let appearance = BuddyAppearance.resolve(
            buddyID: "10-neko-cat", names: ["10-neko-cat": "Pip"], color: .original, catalog: BuddyCatalog(buddies: []))
        #expect(appearance == BuddyAppearance(buddyID: "25-axo-axolotl", name: "Axo", color: .original))
    }

    @Test func colorsHaveTheProductHues() {
        #expect(BuddyColor.allCases.count == 7)
        #expect(BuddyColor.original.targetHue == nil)
        #expect(BuddyColor.rose.targetHue == 330)
        #expect(BuddyColor.orange.targetHue == 30)
        #expect(BuddyColor.lime.targetHue == 95)
        #expect(BuddyColor.teal.targetHue == 175)
        #expect(BuddyColor.sky.targetHue == 205)
        #expect(BuddyColor.violet.targetHue == 275)
        #expect(BuddyColor.sky.title == "Sky")
    }
}
