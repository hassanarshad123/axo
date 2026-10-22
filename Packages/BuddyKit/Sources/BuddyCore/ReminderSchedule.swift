import Foundation

/// The state of all reminders at one moment. A value type: each tick returns a new schedule.
///
///     schedule ──advanced(by: 1s, state: .active)──▶ (new schedule, reminders due now)
///
/// Rules:
/// - `.active` and `.inMeeting` count time for all reminders.
/// - `.away` counts time only for `.wallClock` reminders. After `awayResetThreshold`
///   seconds away, `.activeUse` reminders start again from zero (the user took a break).
/// - `.paused` counts nothing.
/// - Due reminders are delivered only in `.active`. In other states they wait (`pending`).
///   A waiting reminder does not count; its next count starts when it is delivered.
public struct ReminderSchedule: Sendable, Equatable {
    public struct Tick: Sendable, Equatable {
        public let schedule: ReminderSchedule
        public let due: [Reminder]
    }

    /// Counted from the moment the user becomes `.away` (2 minutes after the last input, see
    /// `ActivityState.defaultAwayAfter`). 2 + 3 = a 5-minute break resets sitting reminders.
    public static let defaultAwayResetThreshold: TimeInterval = 3 * 60

    public let reminders: [Reminder]
    /// Seconds counted toward the next fire, per reminder.
    public let elapsed: [Reminder.ID: TimeInterval]
    /// Reminders that are due but wait for the user to be active.
    public let pending: Set<Reminder.ID>
    /// Seconds the user has been away without a break in the away period.
    public let awayStreak: TimeInterval
    public let awayResetThreshold: TimeInterval

    public init(
        reminders: [Reminder],
        elapsed: [Reminder.ID: TimeInterval] = [:],
        pending: Set<Reminder.ID> = [],
        awayStreak: TimeInterval = 0,
        awayResetThreshold: TimeInterval = ReminderSchedule.defaultAwayResetThreshold
    ) {
        self.reminders = reminders
        self.elapsed = elapsed
        self.pending = pending
        self.awayStreak = awayStreak
        self.awayResetThreshold = awayResetThreshold
    }

    /// True when the user has been away long enough to count as a break (sitting reminders restart).
    public var tookBreak: Bool { awayStreak >= awayResetThreshold }

    /// Seconds until the reminder fires, or nil if it is off or unknown.
    public func remaining(for id: Reminder.ID) -> TimeInterval? {
        guard let reminder = reminders.first(where: { $0.id == id }), reminder.isEnabled else {
            return nil
        }
        return max(0, reminder.interval - elapsed[id, default: 0])
    }

    public func advanced(by delta: TimeInterval, state: ActivityState) -> Tick {
        guard delta > 0 else { return Tick(schedule: self, due: []) }

        let newAwayStreak = state == .away ? awayStreak + delta : 0
        let tookBreak = newAwayStreak >= awayResetThreshold

        var newElapsed: [Reminder.ID: TimeInterval] = [:]
        var newPending = pending

        for reminder in reminders where reminder.isEnabled {
            if reminder.timing == .activeUse, tookBreak {
                newPending.remove(reminder.id)
            }
            // A waiting reminder stays at zero until it is delivered, so the next one is a full interval later.
            if newPending.contains(reminder.id) {
                newElapsed[reminder.id] = 0
                continue
            }

            let current = elapsed[reminder.id, default: 0]
            let next = Self.nextElapsed(
                current, delta: delta, timing: reminder.timing, state: state, tookBreak: tookBreak)
            if next >= reminder.interval {
                newPending.insert(reminder.id)
                newElapsed[reminder.id] = 0
            } else {
                newElapsed[reminder.id] = next
            }
        }

        let enabledIDs = Set(reminders.filter(\.isEnabled).map(\.id))
        newPending.formIntersection(enabledIDs)

        let canDeliver = state == .active
        let due = canDeliver ? reminders.filter { newPending.contains($0.id) } : []

        let schedule = ReminderSchedule(
            reminders: reminders,
            elapsed: newElapsed,
            pending: canDeliver ? [] : newPending,
            awayStreak: newAwayStreak,
            awayResetThreshold: awayResetThreshold
        )
        return Tick(schedule: schedule, due: due)
    }

    /// Returns a new schedule with a different reminder list. Progress is kept for reminders that stay.
    public func replacingReminders(_ newReminders: [Reminder]) -> ReminderSchedule {
        let keptIDs = Set(newReminders.map(\.id))
        return ReminderSchedule(
            reminders: newReminders,
            elapsed: elapsed.filter { keptIDs.contains($0.key) },
            pending: pending.intersection(keptIDs),
            awayStreak: awayStreak,
            awayResetThreshold: awayResetThreshold
        )
    }

    /// Returns a new schedule where this reminder starts again from zero (for example, after a snooze).
    public func resetting(_ id: Reminder.ID) -> ReminderSchedule {
        ReminderSchedule(
            reminders: reminders,
            elapsed: elapsed.merging([id: 0]) { _, new in new },
            pending: pending.subtracting([id]),
            awayStreak: awayStreak,
            awayResetThreshold: awayResetThreshold
        )
    }

    /// Returns a new schedule where this reminder fires again after `delay` seconds of counted time.
    public func snoozing(_ id: Reminder.ID, by delay: TimeInterval) -> ReminderSchedule {
        guard let reminder = reminders.first(where: { $0.id == id }) else { return self }
        let elapsedForDelay = max(0, reminder.interval - max(0, delay))
        return ReminderSchedule(
            reminders: reminders,
            elapsed: elapsed.merging([id: elapsedForDelay]) { _, new in new },
            pending: pending.subtracting([id]),
            awayStreak: awayStreak,
            awayResetThreshold: awayResetThreshold
        )
    }

    private static func nextElapsed(
        _ current: TimeInterval,
        delta: TimeInterval,
        timing: Reminder.Timing,
        state: ActivityState,
        tookBreak: Bool
    ) -> TimeInterval {
        switch (timing, state) {
        case (_, .paused):
            return current
        case (.activeUse, .away):
            return tookBreak ? 0 : current
        case (.activeUse, .active), (.activeUse, .inMeeting),
            (.wallClock, .active), (.wallClock, .inMeeting), (.wallClock, .away):
            return current + delta
        }
    }
}
