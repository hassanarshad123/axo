import Foundation
import Testing

@testable import BuddyCore

@Suite("ReminderSchedule")
struct ReminderScheduleTests {
    let standUp = Reminder(kind: .standUp, title: "Stand up", message: "Move", interval: 60)
    let water = Reminder(kind: .drinkWater, title: "Water", message: "Sip", interval: 60, timing: .wallClock)

    @Test("A reminder fires when its interval passes while active")
    func firesWhenDue() {
        let schedule = ReminderSchedule(reminders: [standUp])
        let first = schedule.advanced(by: 59, state: .active)
        #expect(first.due.isEmpty)

        let second = first.schedule.advanced(by: 1, state: .active)
        #expect(second.due == [standUp])
        #expect(second.schedule.remaining(for: standUp.id) == 60)
    }

    @Test("The original schedule does not change (value semantics)")
    func immutability() {
        let schedule = ReminderSchedule(reminders: [standUp])
        _ = schedule.advanced(by: 30, state: .active)
        #expect(schedule.remaining(for: standUp.id) == 60)
    }

    @Test("Reminders wait during a meeting and fire when it ends")
    func heldDuringMeeting() {
        let inCall = ReminderSchedule(reminders: [standUp]).advanced(by: 60, state: .inMeeting)
        #expect(inCall.due.isEmpty)
        #expect(inCall.schedule.pending == [standUp.id])

        let afterCall = inCall.schedule.advanced(by: 1, state: .active)
        #expect(afterCall.due == [standUp])
        #expect(afterCall.schedule.pending.isEmpty)
    }

    @Test("A long enough away period resets sitting reminders but not wall-clock ones")
    func awayResets() {
        let schedule = ReminderSchedule(reminders: [standUp, water], awayResetThreshold: 30)
        let worked = schedule.advanced(by: 40, state: .active).schedule
        let away = worked.advanced(by: 30, state: .away).schedule

        #expect(away.remaining(for: standUp.id) == 60)
        #expect(away.remaining(for: water.id) == 0 || away.pending.contains(water.id))
    }

    @Test("A short away period pauses sitting reminders without a reset")
    func shortAwayPauses() {
        let schedule = ReminderSchedule(reminders: [standUp], awayResetThreshold: 30)
        let worked = schedule.advanced(by: 40, state: .active).schedule
        let away = worked.advanced(by: 10, state: .away).schedule
        #expect(away.remaining(for: standUp.id) == 20)
    }

    @Test("Wall-clock reminders that come due while away fire on return")
    func wallClockWhileAway() {
        let away = ReminderSchedule(reminders: [water]).advanced(by: 60, state: .away)
        #expect(away.due.isEmpty)
        let back = away.schedule.advanced(by: 1, state: .active)
        #expect(back.due == [water])
    }

    @Test("Paused counts nothing")
    func pausedCountsNothing() {
        let paused = ReminderSchedule(reminders: [standUp, water]).advanced(by: 500, state: .paused)
        #expect(paused.due.isEmpty)
        #expect(paused.schedule.remaining(for: standUp.id) == 60)
        #expect(paused.schedule.remaining(for: water.id) == 60)
    }

    @Test("Disabled reminders never fire")
    func disabledNeverFires() {
        let off = standUp.with(isEnabled: false)
        let tick = ReminderSchedule(reminders: [off]).advanced(by: 600, state: .active)
        #expect(tick.due.isEmpty)
        #expect(tick.schedule.remaining(for: off.id) == nil)
    }

    @Test("Replacing reminders keeps progress for reminders that stay")
    func replacingKeepsProgress() {
        let worked = ReminderSchedule(reminders: [standUp, water]).advanced(by: 20, state: .active).schedule
        let edited = worked.replacingReminders([standUp.with(interval: 120)])
        #expect(edited.remaining(for: standUp.id) == 100)
        #expect(edited.remaining(for: water.id) == nil)
    }

    @Test("Resetting starts one reminder again")
    func resetting() {
        let worked = ReminderSchedule(reminders: [standUp]).advanced(by: 50, state: .active).schedule
        #expect(worked.resetting(standUp.id).remaining(for: standUp.id) == 60)
    }

    @Test("Snoozing makes a reminder fire again after the snooze time")
    func snoozing() {
        let fired = ReminderSchedule(reminders: [standUp]).advanced(by: 60, state: .active).schedule
        let snoozed = fired.snoozing(standUp.id, by: 10)
        #expect(snoozed.remaining(for: standUp.id) == 10)
        #expect(snoozed.advanced(by: 10, state: .active).due == [standUp])
    }

    @Test("A held reminder does not count while it waits, and starts again when shown")
    func heldReminderIsFrozen() {
        let held = ReminderSchedule(reminders: [standUp]).advanced(by: 60, state: .inMeeting)
        let longCall = held.schedule.advanced(by: 45, state: .inMeeting)
        #expect(longCall.schedule.pending == [standUp.id])
        #expect(longCall.schedule.remaining(for: standUp.id) == 60)

        let afterCall = longCall.schedule.advanced(by: 5, state: .active)
        #expect(afterCall.due == [standUp])
        #expect(afterCall.schedule.remaining(for: standUp.id) == 60)
    }

    @Test("Water held while away counts from the moment it is shown")
    func heldWaterIsFrozen() {
        let away = ReminderSchedule(reminders: [water]).advanced(by: 60, state: .away)
        let longAway = away.schedule.advanced(by: 50, state: .away)
        let back = longAway.schedule.advanced(by: 5, state: .active)
        #expect(back.due == [water])
        #expect(back.schedule.remaining(for: water.id) == 60)
    }

    @Test("The schedule says when the user took a break")
    func reportsABreak() {
        let schedule = ReminderSchedule(reminders: [standUp], awayResetThreshold: 30)
        #expect(schedule.advanced(by: 30, state: .away).schedule.tookBreak)
        #expect(!schedule.advanced(by: 10, state: .away).schedule.tookBreak)
        #expect(!schedule.advanced(by: 60, state: .active).schedule.tookBreak)
    }

    @Test("Zero or negative time does nothing")
    func zeroDelta() {
        let schedule = ReminderSchedule(reminders: [standUp])
        #expect(schedule.advanced(by: 0, state: .active).schedule == schedule)
        #expect(schedule.advanced(by: -5, state: .active).schedule == schedule)
    }

    @Test("Default reminders match the product spec")
    func defaults() {
        let byKind = Dictionary(uniqueKeysWithValues: Reminder.defaults.map { ($0.kind, $0) })
        #expect(byKind[.standUp]?.interval == TimeInterval(30 * 60))
        #expect(byKind[.eyeRest]?.interval == TimeInterval(20 * 60))
        #expect(byKind[.eyeRest]?.breakDuration == 20)
        #expect(byKind[.drinkWater]?.timing == .wallClock)
        #expect(byKind[.stretch] != nil)
    }
}
