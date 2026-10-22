import Foundation

/// How the buddy looks right now. Each mood maps to one set of character art.
public enum BuddyMood: String, Codable, Sendable, CaseIterable {
    case happy
    case calm
    case worried
    case sleeping
    case stretching
    case celebrating

    /// Picks the mood from what the buddy knows. Order matters: a break beats posture,
    /// and posture beats the default calm face.
    public static func resolve(
        activity: ActivityState,
        posture: PostureAssessment,
        isOnBreak: Bool,
        justLeveledUp: Bool = false
    ) -> BuddyMood {
        if justLeveledUp { return .celebrating }
        if isOnBreak { return .stretching }
        switch activity {
        case .away, .paused:
            return .sleeping
        case .active, .inMeeting:
            switch posture {
            case .good: return .happy
            case .slouching: return .worried
            case .unknown: return .calm
            }
        }
    }
}
