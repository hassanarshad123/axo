import CryptoKit
import Foundation

public enum BuddyPackError: Error, Equatable {
    /// The file does not start like a pack.
    case notAPack
    /// The code does not open this pack, or a byte of the file changed.
    case wrongCode
    /// The pack opened, but what is inside is not a set of buddies the app can show safely.
    case damaged
}

/// Buddies that only people with a code may see (DECISIONS T54). The app ships them locked:
///
///     "AXOPACK1" │ salt (16 bytes) │ AES-GCM: nonce │ locked buddies + PNG art │ tag
///                                       key = HKDF-SHA256(code, salt)
///
/// Without the code, the file shows no image, no name and no id. A changed byte, or a wrong code,
/// makes the GCM tag check fail, so the file cannot be opened at all. All work is on this Mac:
/// no network call.
public struct BuddyPack: Equatable, Sendable {
    public let buddies: [Buddy]
    /// PNG data by buddy id, then by image name ("happy", "form3-neck").
    public let art: [String: [String: Data]]

    /// A pack bigger than this is refused before it is read: all the art of 3 buddies is about 2 MB.
    public static let maximumSize = 32 * 1024 * 1024
    static let magic = Data("AXOPACK1".utf8)
    static let saltLength = 16
    private static let keyInfo = Data("axo buddy pack v1".utf8)
    private static let safeCharacters = Set("abcdefghijklmnopqrstuvwxyz0123456789-")

    public init(buddies: [Buddy], art: [String: [String: Data]]) {
        self.buddies = buddies
        self.art = art
    }

    /// The locked file. A new random salt and nonce each time.
    public func sealed(with code: UnlockCode) throws -> Data {
        guard isSafe else { throw BuddyPackError.damaged }
        let contents = try PropertyListEncoder.binary.encode(Contents(buddies: buddies, art: art))
        let salt = Data((0..<Self.saltLength).map { _ in UInt8.random(in: .min ... .max) })
        let header = Self.magic + salt
        let box = try AES.GCM.seal(contents, using: Self.key(for: code, salt: salt), authenticating: header)
        guard let combined = box.combined else { throw BuddyPackError.damaged }
        return header + combined
    }

    /// Opens a locked file with a code.
    public static func opened(_ data: Data, with code: UnlockCode) throws -> BuddyPack {
        let headerLength = magic.count + saltLength
        guard data.count > headerLength, data.count <= maximumSize, data.prefix(magic.count) == magic else {
            throw BuddyPackError.notAPack
        }
        let header = data.prefix(headerLength)
        let salt = header.suffix(saltLength)
        let contents: Data
        do {
            let box = try AES.GCM.SealedBox(combined: data.dropFirst(headerLength))
            contents = try AES.GCM.open(box, using: key(for: code, salt: salt), authenticating: header)
        } catch {
            throw BuddyPackError.wrongCode
        }
        guard let decoded = try? PropertyListDecoder().decode(Contents.self, from: contents) else {
            throw BuddyPackError.damaged
        }
        let pack = BuddyPack(buddies: decoded.buddies, art: decoded.art)
        guard pack.isSafe else { throw BuddyPackError.damaged }
        return pack
    }

    /// Small letters, digits and dashes only, so an id or an image name can never point at another folder.
    public static func isSafeName(_ name: String) -> Bool {
        !name.isEmpty && name.allSatisfy(safeCharacters.contains) && name.first != "-"
    }

    /// At least one buddy. Each buddy has a safe id and some art. No art for a buddy that is not listed.
    var isSafe: Bool {
        let ids = Set(buddies.map(\.id))
        return !buddies.isEmpty
            && ids.count == buddies.count
            && ids.allSatisfy(Self.isSafeName)
            && Set(art.keys) == ids
            && art.values.allSatisfy { images in !images.isEmpty && images.keys.allSatisfy(Self.isSafeName) }
    }

    private static func key(for code: UnlockCode, salt: Data) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(
            inputKeyMaterial: SymmetricKey(data: Data(code.value.utf8)), salt: salt, info: keyInfo, outputByteCount: 32)
    }

    /// What is inside the lock. `version` lets a later app read an older pack.
    private struct Contents: Codable {
        var version = 1
        let buddies: [Buddy]
        let art: [String: [String: Data]]
    }
}

extension PropertyListEncoder {
    fileprivate static var binary: PropertyListEncoder {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return encoder
    }
}
