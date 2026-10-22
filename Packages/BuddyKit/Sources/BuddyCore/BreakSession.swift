import Foundation

/// One timed break, from start to end. A value type: the state at any moment is a pure function of the time.
///
///     start ──step 1──┬──step 2──┬── ... ──▶ end (finished)
///                     └ the buddy shows each step's pose; the island or the full screen shows the countdown
///
/// A locked break has no Skip button, but holding Esc for `emergencyExitHold` seconds always ends it.
/// Nobody is ever trapped behind a break.
public struct BreakSession: Sendable, Equatable {
    public struct State: Sendable, Equatable {
        /// Nil for a break with no moves (a plain countdown).
        public let stepIndex: Int?
        public let move: StretchMove?
        public let pose: String
        public let instruction: String
        public let stepSecondsLeft: TimeInterval
        public let secondsLeft: TimeInterval
        /// 0 at the start, 1 at the end.
        public let progress: Double
        public var isFinished: Bool { secondsLeft <= 0 }
    }

    public let reminderID: Reminder.ID
    public let kind: Reminder.Kind
    public let title: String
    public let message: String
    public let style: BreakStrictness
    public let startedAt: Date
    public let duration: TimeInterval
    public let steps: [StretchRoutine.Step]

    public static let emergencyExitHold: TimeInterval = 3
    /// How late the break timer may run out and still count as finished.
    static let lateTolerance: TimeInterval = 5

    /// Nil when the reminder has no break time (for example, drink water).
    public init?(reminder: Reminder, style: BreakStrictness, startedAt: Date) {
        guard reminder.breakDuration > 0 else { return nil }
        reminderID = reminder.id
        kind = reminder.kind
        title = reminder.title
        message = reminder.message
        self.style = style
        self.startedAt = startedAt
        duration = reminder.breakDuration
        steps = reminder.routine.steps(fitting: reminder.breakDuration)
    }

    public var endsAt: Date { startedAt.addingTimeInterval(duration) }
    public var canSkip: Bool { style != .fullScreenLocked }
    public var isFullScreen: Bool { style != .gentle }

    public func state(at date: Date) -> State {
        let elapsed = min(max(0, date.timeIntervalSince(startedAt)), duration)
        let secondsLeft = duration - elapsed
        let progress = duration > 0 ? elapsed / duration : 1
        guard let (index, stepEnd) = step(at: elapsed) else {
            return State(
                stepIndex: nil, move: nil, pose: Self.pose(for: kind), instruction: message,
                stepSecondsLeft: secondsLeft, secondsLeft: secondsLeft, progress: progress)
        }
        let move = steps[index].move
        return State(
            stepIndex: index, move: move, pose: move.pose, instruction: move.instruction,
            stepSecondsLeft: stepEnd - elapsed, secondsLeft: secondsLeft, progress: progress)
    }

    /// A countdown as "m:ss". Part of a second counts as a whole one, so "0:00" shows only at the end.
    public static func clockText(_ seconds: TimeInterval) -> String {
        let whole = max(0, Int(seconds.rounded(.up)))
        let minutes = whole / 60
        let rest = whole % 60
        return rest < 10 ? "\(minutes):0\(rest)" : "\(minutes):\(rest)"
    }

    /// The outcome when the break timer runs out at `date`. The timer counts while the Mac sleeps,
    /// so a timer that runs out well after `endsAt` means the Mac slept through the break.
    /// Then the break is interrupted, not finished (no XP, no "break finished" count).
    public func outcomeWhenTimeRunsOut(at date: Date) -> BreakOutcome {
        date.timeIntervalSince(endsAt) > Self.lateTolerance ? .interrupted : .finished
    }

    /// A full-screen break must never cover a paused buddy, a call or a locked screen.
    /// It does not start then, and one that runs ends.
    public static func mayShowFullScreen(isPausedByUser: Bool, isInCall: Bool, isScreenLockedOrAsleep: Bool) -> Bool {
        !isPausedByUser && !isInCall && !isScreenLockedOrAsleep
    }

    /// How far the emergency exit is, 0 to 1. At 1 the break ends.
    public static func emergencyExitProgress(heldFor seconds: TimeInterval) -> Double {
        min(1, max(0, seconds / emergencyExitHold))
    }

    /// The step running after `elapsed` seconds, and the second it ends. The last step runs to the end.
    private func step(at elapsed: TimeInterval) -> (index: Int, end: TimeInterval)? {
        guard !steps.isEmpty else { return nil }
        var end: TimeInterval = 0
        for (index, step) in steps.enumerated() {
            end += step.seconds
            if elapsed < end { return (index, end) }
        }
        return (steps.count - 1, end)
    }

    /// The pose of a break with no moves.
    static func pose(for kind: Reminder.Kind) -> String {
        switch kind {
        case .eyeRest: "eyes"
        case .drinkWater: "water"
        case .standUp: "walk"
        case .stretch, .custom: "stretching"
        }
    }
}

/// How a due reminder reaches the user.
public enum BreakDelivery: Sendable, Equatable {
    /// A prompt in the island. Done starts the break (in the island for gentle breaks).
    case prompt
    /// A short notice in the island, then the full-screen break.
    case fullScreen(notice: TimeInterval, canSnooze: Bool)
}

public extension BreakStrictness {
    /// Seconds between the notice in the island and the full-screen break. A locked break gets
    /// more time, because the user cannot skip it: time to end a sentence or a call.
    var notice: TimeInterval {
        switch self {
        case .gentle: 0
        case .fullScreenSkippable: 10
        case .fullScreenLocked: 30
        }
    }

    func delivery(for reminder: Reminder) -> BreakDelivery {
        guard reminder.breakDuration > 0 else { return .prompt }
        switch self {
        case .gentle: return .prompt
        case .fullScreenSkippable: return .fullScreen(notice: notice, canSnooze: true)
        case .fullScreenLocked: return .fullScreen(notice: notice, canSnooze: false)
        }
    }
}
