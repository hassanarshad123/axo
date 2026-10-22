import Foundation

/// A short scene the buddy plays for a few seconds, then goes back to its mood.
/// The duo (two buddies together) has art for each one (DECISIONS #39). Other buddies show a close pose
/// (`BuddyAssets.fallbacks`).
public enum BuddyMoment: String, CaseIterable, Sendable {
    /// The app started.
    case hello
    /// A stand-up break started.
    case walkBreak
    /// The user came back to the Mac.
    case focus
    /// A water reminder was done.
    case chaiBreak
    /// Posture is good again after a nudge.
    case goodJob
    /// A break ran to the end.
    case breakDone
    /// A breathing step started.
    case breathe
    /// The weekly goal was reached.
    case weeklyGoal
    /// The daily goal, a streak, a new level or a new form.
    case celebrate

    public static let showFor: TimeInterval = 4

    public var pose: String {
        switch self {
        case .hello: "wave"
        case .walkBreak: "walk"
        case .focus: "laptop"
        case .chaiBreak: "chai"
        case .goodJob: "thumbs-up"
        case .breakDone: "fist-bump"
        case .breathe: "breathe"
        case .weeklyGoal: "trophy"
        case .celebrate: "celebrate"
        }
    }
}
