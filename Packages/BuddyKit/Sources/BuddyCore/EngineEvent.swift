import Foundation

/// Something that happened in the app. The engine sends each event to its listeners
/// (history, voice, usage counts), so the engine itself stays small.
///
///     BuddyEngine ──event──▶ [history] [voice coach] [usage counts] ...
public enum EngineEvent: Sendable, Equatable {
    case appStarted
    /// The user came back after being away for this many seconds.
    case cameBack(awayFor: TimeInterval)
    case reminderDue(Reminder)
    case reminderDone(Reminder)
    case reminderSnoozed(Reminder)
    case breakStarted(BreakSession)
    case breakEnded(BreakSession, BreakOutcome)
    /// `sensor` decided the result. Nil when no sensor saw the user.
    case postureChecked(PostureAssessment, sensor: PostureReading.Source?)
    case postureNudged(PostureAssessment)
    /// Posture is good again after a nudge.
    case postureFixed
    /// The user was at the Mac (active or in a call) for this many seconds since the last tick.
    case atMac(seconds: TimeInterval)
    case milestone(ProgressMilestone)
    case calibrationStarted
    /// False when no sensor saw the user, so no good posture was saved.
    case calibrationEnded(succeeded: Bool)
    /// The user finished the setup window with this buddy.
    case setupFinished(buddyID: String)
    /// The user picked another buddy in Settings.
    case buddyPicked(buddyID: String)
}

/// How a break ended.
public enum BreakOutcome: String, Codable, Sendable, CaseIterable {
    /// It ran to the end.
    case finished
    /// The user pressed Skip or End.
    case skipped
    /// The user held Esc or "Hold to leave" on a locked break.
    case emergencyExit
    /// A call started, or the screen locked or slept.
    case interrupted
}
