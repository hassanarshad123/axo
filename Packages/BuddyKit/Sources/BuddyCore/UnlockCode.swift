import Foundation

/// A code that opens a locked buddy pack (`BuddyPack`). Hassan gives it to the people who may see
/// those buddies. It is 16 characters from Crockford's base32 set, shown as "7KQ3-XW9P-2M4T-HB6R".
///
/// 16 random characters × 5 bits = 80 bits, too many to guess, so the locked files in the public app
/// stay shut. Make codes only with `random()` (`swift run axo-pack new-code`), never by hand.
public struct UnlockCode: Hashable, Sendable, Codable {
    /// Crockford's base32: digits and capital letters without I, L, O and U, which look like 1, 1, 0 and V.
    public static let alphabet = Array("0123456789ABCDEFGHJKMNPQRSTVWXYZ")
    public static let length = 16
    private static let groupLength = 4
    /// Typed characters that mean a character of the set.
    private static let lookAlikes: [Character: Character] = ["O": "0", "I": "1", "L": "1"]
    /// Typed characters that only make the code easier to read.
    private static let separators: Set<Character> = [" ", "-", "_", "\t", "\n", "\r"]

    /// The 16 characters, capitals, no dashes.
    public let value: String

    /// Reads a typed code. Small letters, spaces and dashes are fine. Nil when it is not a code.
    public init?(_ text: String) {
        let characters = text.uppercased()
            .filter { !Self.separators.contains($0) }
            .map { Self.lookAlikes[$0] ?? $0 }
        guard characters.count == Self.length, characters.allSatisfy(Self.alphabet.contains) else { return nil }
        value = String(characters)
    }

    /// The code as people type it: "7KQ3-XW9P-2M4T-HB6R".
    public var display: String {
        stride(from: 0, to: Self.length, by: Self.groupLength)
            .map { start in
                let from = value.index(value.startIndex, offsetBy: start)
                return String(value[from..<value.index(from, offsetBy: Self.groupLength)])
            }
            .joined(separator: "-")
    }

    /// A new code from the system's secure random numbers.
    public static func random() -> UnlockCode {
        var generator = SystemRandomNumberGenerator()
        return random(using: &generator)
    }

    /// 5 random bits per character. 32 divides 2^64, so every character is equally likely.
    public static func random<Generator: RandomNumberGenerator>(using generator: inout Generator) -> UnlockCode {
        let characters = (0..<length).map { _ in alphabet[Int(generator.next() & 31)] }
        // The characters all come from the set, so this cannot fail.
        return UnlockCode(String(characters))!
    }

    // Saved as the plain 16 characters. A saved text that is not a code fails to decode.
    public init(from decoder: Decoder) throws {
        let text = try decoder.singleValueContainer().decode(String.self)
        guard let code = UnlockCode(text) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not a code"))
        }
        self = code
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
