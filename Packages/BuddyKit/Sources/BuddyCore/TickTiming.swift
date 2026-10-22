import Foundation

/// How much time a reminder tick counts, and as what.
///
/// The engine measures the real time since the last tick. Normally that is about 5 s.
/// A much longer gap means the Mac slept (lid closed) or the app froze. The user was not
/// sitting at the Mac then, so the whole gap counts as `.away`:
///
///     tick ── 5 s ── tick ─────────── 1 h (lid closed) ─────────── tick
///          current state                 counted as .away
public enum TickTiming {
    /// A tick later than this means the Mac slept or the app could not run.
    public static let maximumGap: TimeInterval = 30

    /// The state to count for the time since the last tick. A manual pause always stays a pause.
    public static func countedState(
        elapsed: TimeInterval,
        current: ActivityState,
        maximumGap: TimeInterval = maximumGap
    ) -> ActivityState {
        if current == .paused { return .paused }
        return elapsed > maximumGap ? .away : current
    }
}
