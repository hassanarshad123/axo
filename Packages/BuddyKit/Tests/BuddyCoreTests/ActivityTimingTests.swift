import Foundation
import Testing

@testable import BuddyCore

@Suite("ActivityState and the screen")
struct ActivityScreenTests {
    @Test("A locked or sleeping screen counts as away")
    func lockedIsAway() {
        let state = ActivityState.resolve(
            idleSeconds: 0, microphoneInUse: false, isPausedByUser: false, isScreenLockedOrAsleep: true)
        #expect(state == .away)
    }

    @Test("A locked screen beats the microphone")
    func lockBeatsCall() {
        let state = ActivityState.resolve(
            idleSeconds: 0, microphoneInUse: true, isPausedByUser: false, isScreenLockedOrAsleep: true)
        #expect(state == .away)
    }

    @Test func pauseBeatsLock() {
        let state = ActivityState.resolve(
            idleSeconds: 0, microphoneInUse: false, isPausedByUser: true, isScreenLockedOrAsleep: true)
        #expect(state == .paused)
    }
}

@Suite("TickTiming")
struct TickTimingTests {
    let standUp = Reminder(kind: .standUp, title: "Stand up", message: "Move", interval: 30 * 60)
    let water = Reminder(kind: .drinkWater, title: "Water", message: "Sip", interval: 60 * 60, timing: .wallClock)

    @Test("A normal tick counts the current state")
    func normalTick() {
        #expect(TickTiming.countedState(elapsed: 5, current: .active) == .active)
        #expect(TickTiming.countedState(elapsed: 30, current: .inMeeting) == .inMeeting)
    }

    @Test("A gap longer than 30 s counts as away (the Mac slept)")
    func longGapIsAway() {
        #expect(TickTiming.countedState(elapsed: 31, current: .active) == .away)
        #expect(TickTiming.countedState(elapsed: 3600, current: .inMeeting) == .away)
    }

    @Test("A manual pause stays a pause, even over a long gap")
    func pauseIsKept() {
        #expect(TickTiming.countedState(elapsed: 3600, current: .paused) == .paused)
    }

    @Test("A lunch with the lid closed resets the sitting reminders")
    func lidClosedLunchIsABreak() {
        let worked = ReminderSchedule(reminders: [standUp]).advanced(by: 25 * 60, state: .active).schedule
        let gap: TimeInterval = 60 * 60
        let afterLunch = worked.advanced(by: gap, state: TickTiming.countedState(elapsed: gap, current: .active))
        #expect(afterLunch.due.isEmpty)
        #expect(afterLunch.schedule.remaining(for: standUp.id) == 1800)  // a full 30 minutes again
    }

    @Test("Wall-clock reminders count the sleep and show after it")
    func wallClockCountsTheSleep() {
        let gap: TimeInterval = 61 * 60
        let afterSleep = ReminderSchedule(reminders: [water])
            .advanced(by: gap, state: TickTiming.countedState(elapsed: gap, current: .active))
        #expect(afterSleep.schedule.pending == [water.id])
        #expect(afterSleep.schedule.advanced(by: 5, state: .active).due == [water])
    }
}

@Suite("PostureCheckPolicy")
struct PostureCheckPolicyTests {
    private func sensors(
        activity: ActivityState = .active,
        idle: TimeInterval = 5,
        locked: Bool = false,
        camera: Bool = true,
        headphones: Bool = true
    ) -> PostureCheckPolicy.Sensors {
        PostureCheckPolicy.sensors(
            activity: activity,
            idleSeconds: idle,
            isScreenLockedOrAsleep: locked,
            cameraEnabled: camera,
            headphonesEnabled: headphones
        )
    }

    @Test("The camera runs only while the user touched the Mac in the last 30 s")
    func cameraNeedsRecentInput() {
        #expect(sensors(idle: 29).camera)
        #expect(!sensors(idle: 30).camera)
        #expect(sensors(idle: 90).headphones)
    }

    @Test("No check while away, in a call or paused")
    func onlyWhenActive() {
        #expect(sensors(activity: .away) == .none)
        #expect(sensors(activity: .inMeeting) == .none)
        #expect(sensors(activity: .paused) == .none)
        #expect(!sensors(activity: .away).any)
    }

    @Test("No check while the screen is locked or asleep")
    func notWhenLocked() {
        #expect(sensors(locked: true) == .none)
    }

    @Test("Sensors turned off in Settings stay off")
    func settingsWin() {
        #expect(!sensors(camera: false).camera)
        #expect(!sensors(headphones: false).headphones)
        #expect(sensors(camera: false, headphones: false) == .none)
    }
}
