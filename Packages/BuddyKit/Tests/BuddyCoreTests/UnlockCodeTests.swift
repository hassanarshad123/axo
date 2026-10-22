import Foundation
import Testing

@testable import BuddyCore

@Suite("Unlock code")
struct UnlockCodeTests {
    /// Gives the same numbers every run, so a made code can be checked.
    private struct CountingGenerator: RandomNumberGenerator {
        var count: UInt64 = 0

        mutating func next() -> UInt64 {
            defer { count &+= 1 }
            return count
        }
    }

    @Test("Typed codes are read the same with or without dashes, spaces or small letters")
    func typingVariants() throws {
        let code = try #require(UnlockCode("7KQ3-XW9P-2M4T-HB6R"))
        #expect(code.value == "7KQ3XW9P2M4THB6R")
        #expect(UnlockCode("7kq3 xw9p 2m4t hb6r") == code)
        #expect(UnlockCode(" 7KQ3XW9P2M4THB6R\n") == code)
        #expect(UnlockCode("7kq3_xw9p-2m4t hb6r") == code)
    }

    @Test("Letters that look like digits count as those digits: O is 0, I and L are 1")
    func lookAlikes() {
        #expect(UnlockCode("OOOO-IIII-LLLL-0000")?.value == "0000111111110000")
    }

    @Test(
        "A code with the wrong length or a letter outside the set is not a code",
        arguments: ["", "7KQ3-XW9P-2M4T", "7KQ3-XW9P-2M4T-HB6R-A", "7KQ3-XW9P-2M4T-HB6U", "7KQ3-XW9P-2M4T-HB6!"])
    func notACode(_ text: String) {
        #expect(UnlockCode(text) == nil)
    }

    @Test("The code shows in 4 groups of 4")
    func display() {
        #expect(UnlockCode("7kq3xw9p2m4thb6r")?.display == "7KQ3-XW9P-2M4T-HB6R")
    }

    @Test("A made code has 16 characters from the set, and two made codes are not the same")
    func random() throws {
        let code = UnlockCode.random()
        #expect(code.value.count == UnlockCode.length)
        #expect(code.value.allSatisfy { UnlockCode.alphabet.contains($0) })
        #expect(UnlockCode(code.display) == code)
        #expect(UnlockCode.random() != code)
    }

    @Test("A made code uses the whole set (5 bits per character, 80 bits in all)")
    func randomUsesTheWholeAlphabet() {
        var generator = CountingGenerator()
        let codes = (0..<2).map { _ in UnlockCode.random(using: &generator).value }.joined()
        #expect(Set(codes) == Set(UnlockCode.alphabet))
    }
}
