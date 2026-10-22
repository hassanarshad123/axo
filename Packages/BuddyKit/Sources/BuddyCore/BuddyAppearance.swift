import Foundation

/// The colors a user can give the buddy. Each one turns the buddy's main color to a target hue.
public enum BuddyColor: String, Codable, Sendable, CaseIterable, Identifiable {
    case original
    case rose
    case orange
    case lime
    case teal
    case sky
    case violet

    public var id: String { rawValue }

    public var title: String { rawValue.capitalized }

    /// The hue (degrees) the main color turns to. Nil keeps the art as drawn.
    public var targetHue: Double? {
        switch self {
        case .original: nil
        case .rose: 330
        case .orange: 30
        case .lime: 95
        case .teal: 175
        case .sky: 205
        case .violet: 275
        }
    }

    /// A color this close (degrees) to the buddy's own main color looks the same as `.original`.
    public static let sameColorDistance: Double = 25

    /// The colors to offer for a buddy: all but the ones that look like its own color.
    /// `selected` always stays, so the saved choice is never hidden.
    public static func choices(for buddy: Buddy, keeping selected: BuddyColor) -> [BuddyColor] {
        allCases.filter { color in
            guard color != selected, let target = color.targetHue else { return true }
            return HueSwap.distance(target, buddy.mainHue) > sameColorDistance
        }
    }
}

/// The menu bar icon: one-color (follows light and dark menu bars) or the buddy's head in color.
public enum MenuBarIconStyle: String, Codable, Sendable, CaseIterable, Identifiable {
    case outline
    case color

    public var id: String { rawValue }

    public var title: String { rawValue.capitalized }
}

/// Rules for the name the user gives the buddy.
public enum BuddyName {
    public static let maximumLength = 16

    /// What to save: cut to 16 characters. Nil (use the buddy's own name) when there is no visible text.
    /// Spaces are kept, so the user can type "Mr Pip" one key at a time.
    public static func limited(_ text: String?) -> String? {
        guard let text else { return nil }
        let cut = String(text.prefix(maximumLength))
        return cut.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : cut
    }

    /// What to show: the trimmed custom name, or the buddy's own name.
    public static func display(custom: String?, default defaultName: String) -> String {
        let trimmed = custom?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? defaultName : trimmed
    }

    /// Each buddy keeps its own name (buddy id → name). Returns new names with only `id` changed.
    /// An empty name removes the entry, so that buddy shows its own name again.
    public static func names(_ names: [String: String], setting name: String?, for id: String) -> [String: String] {
        var updated = names
        updated[id] = limited(name)
        return updated
    }
}

/// Everything the island needs to draw the buddy.
public struct BuddyAppearance: Sendable, Equatable {
    public let buddyID: String
    /// The name to show (the user's name for it, or the buddy's own name).
    public let name: String
    public let color: BuddyColor
    /// The growth form from the level, 1 (baby) to 5. A form out of range shows the plain art.
    public let form: Int

    public init(buddyID: String, name: String, color: BuddyColor, form: Int = BuddyAssets.plainForm) {
        self.buddyID = buddyID
        self.name = name
        self.color = color
        self.form = BuddyAssets.forms.contains(form) ? form : BuddyAssets.plainForm
    }

    public static let axo = BuddyAppearance(buddyID: BuddyCatalog.defaultBuddyID, name: "Axo", color: .original)

    /// Turns saved settings into an appearance. A buddy that is not in the catalog becomes Axo.
    /// `names` holds the user's name for each buddy id. The name of the buddy that shows is used.
    public static func resolve(
        buddyID: String,
        names: [String: String],
        color: BuddyColor,
        catalog: BuddyCatalog,
        form: Int = BuddyAssets.plainForm
    ) -> BuddyAppearance {
        let buddy = catalog.resolvedBuddy(id: buddyID)
        let id = buddy?.id ?? axo.buddyID
        return BuddyAppearance(
            buddyID: id,
            name: BuddyName.display(custom: names[id], default: buddy?.name ?? axo.name),
            color: color,
            form: form
        )
    }
}
