import Foundation

/// What the user is doing right now, as far as the buddy can tell.
public enum ActivityState: String, Codable, Sendable, Equatable {
    /// At the Mac, keyboard or mouse in use.
    case active
    /// At the Mac, but in a call. Reminders wait until the call ends.
    case inMeeting
    /// No keyboard or mouse input for a while.
    case away
    /// The user paused the buddy by hand.
    case paused

    /// Seconds without keyboard or mouse input before the user counts as away.
    public static let defaultAwayAfter: TimeInterval = 2 * 60

    /// Order matters: a manual pause wins, then a locked or sleeping screen (the user left),
    /// then a call (people sit still in calls), then idle time. A person the camera just saw
    /// (`Presence`) is still at the Mac, reading, even with no input.
    public static func resolve(
        idleSeconds: TimeInterval,
        microphoneInUse: Bool,
        isPausedByUser: Bool,
        isScreenLockedOrAsleep: Bool = false,
        isPersonPresent: Bool = false,
        awayAfter: TimeInterval = defaultAwayAfter
    ) -> ActivityState {
        if isPausedByUser { return .paused }
        if isScreenLockedOrAsleep { return .away }
        if microphoneInUse { return .inMeeting }
        if idleSeconds >= awayAfter, !isPersonPresent { return .away }
        return .active
    }
}
