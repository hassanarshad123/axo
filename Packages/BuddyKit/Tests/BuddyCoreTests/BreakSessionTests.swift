import Foundation
import Testing

@testable import BuddyCore

@Suite("BreakSession")
struct BreakSessionTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)
    private let stretch = Reminder.defaults[2]  // 90 s, neck and shoulders
    private let water = Reminder.defaults[3]  // no break

    @Test("A reminder with no break time gives no session")
    func noBreakNoSession() {
        #expect(BreakSession(reminder: water, style: .gentle, startedAt: start) == nil)
    }

    @Test("The state follows the routine steps over time")
    func stateOverTime() throws {
        let session = try #require(BreakSession(reminder: stretch, style: .gentle, startedAt: start))
        #expect(session.duration == 90)
        #expect(session.endsAt == start.addingTimeInterval(90))

        let first = session.state(at: start)
        #expect(first.move == .neckLeft)
        #expect(first.stepIndex == 0)
        #expect(first.stepSecondsLeft == 15)
        #expect(first.secondsLeft == 90)
        #expect(!first.isFinished)

        let later = session.state(at: start.addingTimeInterval(16))
        #expect(later.move == .neckRight)
        #expect(later.stepIndex == 1)
        #expect(later.stepSecondsLeft == 14)
        #expect(later.secondsLeft == 74)
        #expect(later.pose == "neck-right")
        #expect(later.instruction == StretchMove.neckRight.instruction)
    }

    @Test("At the end the session is finished, and never goes below zero")
    func finishes() throws {
        let session = try #require(BreakSession(reminder: stretch, style: .gentle, startedAt: start))
        let end = session.state(at: start.addingTimeInterval(90))
        #expect(end.isFinished)
        #expect(end.secondsLeft == 0)
        #expect(end.progress == 1)
        #expect(session.state(at: start.addingTimeInterval(500)).secondsLeft == 0)
        // A clock that moved back counts as the start.
        #expect(session.state(at: start.addingTimeInterval(-30)).secondsLeft == 90)
        #expect(session.state(at: start.addingTimeInterval(45)).progress == 0.5)
    }

    @Test("A timer-only break shows the reminder's own pose and message")
    func timerOnly() throws {
        let custom = Reminder(
            kind: .custom, title: "Pray", message: "Time to pray.", interval: 3600, breakDuration: 300)
        let session = try #require(BreakSession(reminder: custom, style: .gentle, startedAt: start))
        let state = session.state(at: start.addingTimeInterval(10))
        #expect(state.move == nil)
        #expect(state.stepIndex == nil)
        #expect(state.pose == "stretching")
        #expect(state.instruction == "Time to pray.")
        #expect(state.secondsLeft == 290)
        #expect(state.stepSecondsLeft == 290)

        let eyes = Reminder.defaults[1].withRoutine(StretchRoutine.timer.id)
        let eyeState = try #require(BreakSession(reminder: eyes, style: .gentle, startedAt: start)).state(at: start)
        #expect(eyeState.pose == "eyes")
    }

    @Test("Only a locked break cannot be skipped")
    func skipping() throws {
        #expect(try #require(BreakSession(reminder: stretch, style: .gentle, startedAt: start)).canSkip)
        let skippable = try #require(BreakSession(reminder: stretch, style: .fullScreenSkippable, startedAt: start))
        #expect(skippable.canSkip)
        #expect(skippable.isFullScreen)
        let locked = try #require(BreakSession(reminder: stretch, style: .fullScreenLocked, startedAt: start))
        #expect(!locked.canSkip)
        #expect(locked.isFullScreen)
    }

    @Test("Holding Esc for 3 s always opens a locked break")
    func emergencyExit() {
        #expect(BreakSession.emergencyExitHold == 3)
        #expect(BreakSession.emergencyExitProgress(heldFor: 0) == 0)
        #expect(BreakSession.emergencyExitProgress(heldFor: 1.5) == 0.5)
        #expect(BreakSession.emergencyExitProgress(heldFor: 3) == 1)
        #expect(BreakSession.emergencyExitProgress(heldFor: 9) == 1)
        #expect(BreakSession.emergencyExitProgress(heldFor: -1) == 0)
    }

    @Test("Gentle breaks start from the island; full-screen styles give a short notice first")
    func delivery() {
        #expect(BreakStrictness.gentle.delivery(for: stretch) == .prompt)
        #expect(BreakStrictness.fullScreenSkippable.delivery(for: stretch) == .fullScreen(notice: 10, canSnooze: true))
        // A locked break cannot be skipped, so its notice is longer.
        #expect(BreakStrictness.fullScreenLocked.delivery(for: stretch) == .fullScreen(notice: 30, canSnooze: false))
        // A reminder with no break time is always a plain prompt.
        #expect(BreakStrictness.fullScreenLocked.delivery(for: water) == .prompt)
    }

    @Test("The countdown reads m:ss and shows 0:00 only at the end")
    func clockText() {
        #expect(BreakSession.clockText(90) == "1:30")
        #expect(BreakSession.clockText(65) == "1:05")
        #expect(BreakSession.clockText(9.2) == "0:10")
        #expect(BreakSession.clockText(0.1) == "0:01")
        #expect(BreakSession.clockText(0) == "0:00")
        #expect(BreakSession.clockText(-4) == "0:00")
    }

    @Test("A timer that runs out long after the planned end means the Mac slept: interrupted, not finished")
    func sleepInterrupts() throws {
        let session = try #require(BreakSession(reminder: stretch, style: .gentle, startedAt: start))
        #expect(session.outcomeWhenTimeRunsOut(at: session.endsAt) == .finished)
        #expect(session.outcomeWhenTimeRunsOut(at: session.endsAt.addingTimeInterval(2)) == .finished)
        #expect(session.outcomeWhenTimeRunsOut(at: session.endsAt.addingTimeInterval(600)) == .interrupted)
    }

    @Test("A full-screen break never shows while paused, in a call or with the screen locked")
    func fullScreenRule() {
        #expect(BreakSession.mayShowFullScreen(isPausedByUser: false, isInCall: false, isScreenLockedOrAsleep: false))
        #expect(!BreakSession.mayShowFullScreen(isPausedByUser: true, isInCall: false, isScreenLockedOrAsleep: false))
        #expect(!BreakSession.mayShowFullScreen(isPausedByUser: false, isInCall: true, isScreenLockedOrAsleep: false))
        #expect(!BreakSession.mayShowFullScreen(isPausedByUser: false, isInCall: false, isScreenLockedOrAsleep: true))
    }
}
