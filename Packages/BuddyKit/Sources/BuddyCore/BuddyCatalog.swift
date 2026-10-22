import Foundation

/// One buddy the user can pick. Read from `catalog.json`, which `scripts/export-buddy-assets.py` writes.
public struct Buddy: Codable, Sendable, Equatable, Identifiable {
    /// The folder name of its art, for example "25-axo-axolotl".
    public let id: String
    public let number: Int
    /// The buddy's own name, for example "Axo". The user can give it another one.
    public let name: String
    /// The hue of the buddy's main color, in degrees (0 to 360). A color choice turns this hue.
    public let mainHue: Double
    /// The middle of the window of hues that turn with the main color. Usually `mainHue`.
    public let hueCenter: Double
    /// How far (in degrees) a hue may be from `hueCenter` and still turn.
    public let hueTolerance: Double
    /// Pixels with less saturation keep their color (see `HueSwap`).
    public let minSaturation: Double
    /// Darker pixels keep their color (see `HueSwap`).
    public let minValue: Double

    public init(
        id: String,
        number: Int,
        name: String,
        mainHue: Double,
        hueCenter: Double? = nil,
        hueTolerance: Double = HueSwap.defaultTolerance,
        minSaturation: Double = HueSwap.defaultMinimumSaturation,
        minValue: Double = 0
    ) {
        self.id = id
        self.number = number
        self.name = name
        self.mainHue = mainHue
        self.hueCenter = hueCenter ?? mainHue
        self.hueTolerance = hueTolerance
        self.minSaturation = minSaturation
        self.minValue = minValue
    }

    private enum CodingKeys: String, CodingKey {
        case id, number, name, mainHue, hueCenter, hueTolerance, minSaturation, minValue
    }

    /// `id`, `name` and `mainHue` are required. The rest get defaults. Unknown keys are ignored.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            number: try container.decodeIfPresent(Int.self, forKey: .number) ?? 0,
            name: try container.decode(String.self, forKey: .name),
            mainHue: try container.decode(Double.self, forKey: .mainHue),
            hueCenter: try container.decodeIfPresent(Double.self, forKey: .hueCenter),
            hueTolerance: try container.decodeIfPresent(Double.self, forKey: .hueTolerance) ?? HueSwap.defaultTolerance,
            minSaturation: try container.decodeIfPresent(Double.self, forKey: .minSaturation)
                ?? HueSwap.defaultMinimumSaturation,
            minValue: try container.decodeIfPresent(Double.self, forKey: .minValue) ?? 0
        )
    }
}

/// All buddies the user can pick, in the order the art script wrote them.
public struct BuddyCatalog: Codable, Sendable, Equatable {
    /// Axo, the pink axolotl. The default buddy, and the fallback for an unknown id.
    public static let defaultBuddyID = "25-axo-axolotl"

    public let buddies: [Buddy]

    public init(buddies: [Buddy]) {
        self.buddies = buddies
    }

    private enum CodingKeys: String, CodingKey {
        case buddies
    }

    /// A broken buddy entry is skipped, so one bad line does not hide every buddy.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let entries = try container.decode([LossyBuddy].self, forKey: .buddies)
        self.init(buddies: entries.compactMap(\.buddy))
    }

    public static func decoded(from data: Data) throws -> BuddyCatalog {
        try JSONDecoder().decode(BuddyCatalog.self, from: data)
    }

    public func buddy(withID id: String) -> Buddy? {
        buddies.first { $0.id == id }
    }

    /// The buddy to show for a saved id: that buddy, else Axo, else the first one.
    /// Nil only when the catalog is empty.
    public func resolvedBuddy(id: String?) -> Buddy? {
        id.flatMap(buddy(withID:)) ?? buddy(withID: Self.defaultBuddyID) ?? buddies.first
    }

    private struct LossyBuddy: Decodable {
        let buddy: Buddy?

        init(from decoder: Decoder) throws {
            buddy = try? Buddy(from: decoder)
        }
    }
}
