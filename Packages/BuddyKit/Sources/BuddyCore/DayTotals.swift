import Foundation

/// One local day of progress: posture checks, breaks, reminders and time at the Mac.
/// The Progress window, the streak and the XP all read these. A value type: each change returns a new value.
public struct DayTotals: Codable, Sendable, Equatable {
    /// The start of the local day.
    public let day: Date
    public let goodChecks: Int
    /// Good and slouching checks. Unknown checks (nobody seen) do not count.
    public let knownChecks: Int
    public let breaksFinished: Int
    public let remindersDone: Int
    public let secondsAtMac: TimeInterval
    /// The score reached the goal with enough checks. It stays true for the day once reached.
    public let goalReached: Bool

    /// The daily goal: a score of 70 or more...
    public static let goalScore = 70
    /// ...from at least 10 known checks, so 2 lucky checks are not a goal day.
    public static let checksForGoal = 10

    public init(
        day: Date,
        goodChecks: Int = 0,
        knownChecks: Int = 0,
        breaksFinished: Int = 0,
        remindersDone: Int = 0,
        secondsAtMac: TimeInterval = 0,
        goalReached: Bool = false
    ) {
        self.day = day
        self.goodChecks = goodChecks
        self.knownChecks = knownChecks
        self.breaksFinished = breaksFinished
        self.remindersDone = remindersDone
        self.secondsAtMac = secondsAtMac
        self.goalReached = goalReached
    }

    public static func empty(on date: Date, calendar: Calendar = .current) -> DayTotals {
        DayTotals(day: calendar.startOfDay(for: date))
    }

    /// Percent of known checks that were good, from 0 to 100. Nil when there is no known check yet.
    public var score: Int? {
        guard knownChecks > 0 else { return nil }
        return Int((Double(goodChecks) / Double(knownChecks) * 100).rounded())
    }

    public func recording(_ assessment: PostureAssessment) -> DayTotals {
        guard assessment != .unknown else { return self }
        let good = goodChecks + (assessment.isGood ? 1 : 0)
        let known = knownChecks + 1
        let next = copy(goodChecks: good, knownChecks: known)
        let reached = known >= Self.checksForGoal && (next.score ?? 0) >= Self.goalScore
        return next.copy(goalReached: goalReached || reached)
    }

    public func recordingBreakFinished() -> DayTotals {
        copy(breaksFinished: breaksFinished + 1)
    }

    public func recordingReminderDone() -> DayTotals {
        copy(remindersDone: remindersDone + 1)
    }

    public func addingTimeAtMac(_ seconds: TimeInterval) -> DayTotals {
        copy(secondsAtMac: secondsAtMac + max(seconds, 0))
    }

    private func copy(
        goodChecks: Int? = nil,
        knownChecks: Int? = nil,
        breaksFinished: Int? = nil,
        remindersDone: Int? = nil,
        secondsAtMac: TimeInterval? = nil,
        goalReached: Bool? = nil
    ) -> DayTotals {
        DayTotals(
            day: day,
            goodChecks: goodChecks ?? self.goodChecks,
            knownChecks: knownChecks ?? self.knownChecks,
            breaksFinished: breaksFinished ?? self.breaksFinished,
            remindersDone: remindersDone ?? self.remindersDone,
            secondsAtMac: secondsAtMac ?? self.secondsAtMac,
            goalReached: goalReached ?? self.goalReached
        )
    }
}
