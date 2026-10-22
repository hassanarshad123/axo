import Foundation

/// How hard a break reminder is to ignore. The user picks it in Settings. Default: gentle.
public enum BreakStrictness: String, Codable, Sendable, CaseIterable {
    /// The island shows the reminder. Easy to ignore.
    case gentle
    /// A full-screen break page with a countdown and a Skip button.
    case fullScreenSkippable
    /// A full-screen break page that stays until the break ends.
    case fullScreenLocked

    public var title: String {
        switch self {
        case .gentle: "Gentle (notch only)"
        case .fullScreenSkippable: "Full screen, can skip"
        case .fullScreenLocked: "Full screen, locked"
        }
    }
}
