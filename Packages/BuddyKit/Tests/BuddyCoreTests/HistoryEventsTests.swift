import Foundation
import Testing

@testable import BuddyCore

@Suite("Events into history")
struct HistoryEventsTests {
    private let now = Date(timeIntervalSince1970: 1_792_000_000)
    private let stretch = Reminder.defaults[2]
    private var day: DayTotals { DayTotals(day: now) }

    @Test("A posture check is a record and counts in the day")
    func postureCheck() {
        let event = EngineEvent.postureChecked(.slouching([.leaningIn]), sensor: .camera)
        #expect(
            event.historyRecord(at: now)
                == .check(PostureCheckRecord(date: now, assessment: .slouching([.leaningIn]), sensor: .camera)))
        #expect(day.applying(event).knownChecks == 1)
    }

    @Test("Reminders: shown, done and snoozed are records; done counts in the day")
    func reminders() {
        #expect(
            EngineEvent.reminderDue(stretch).historyRecord(at: now)
                == .reminder(ReminderRecord(date: now, kind: .stretch, outcome: .shown)))
        #expect(EngineEvent.reminderSnoozed(stretch).historyRecord(at: now)?.reminderOutcome == .snoozed)
        #expect(EngineEvent.reminderDone(stretch).historyRecord(at: now)?.reminderOutcome == .done)
        #expect(day.applying(.reminderDone(stretch)).remindersDone == 1)
        #expect(day.applying(.reminderSnoozed(stretch)) == day)
    }

    @Test("A finished break counts; a skipped break is only a record")
    func breaks() throws {
        let session = try #require(BreakSession(reminder: stretch, style: .gentle, startedAt: now))
        #expect(EngineEvent.breakEnded(session, .finished).historyRecord(at: now)?.reminderOutcome == .breakFinished)
        #expect(day.applying(.breakEnded(session, .finished)).breaksFinished == 1)
        #expect(day.applying(.breakEnded(session, .skipped)) == day)
        #expect(EngineEvent.breakStarted(session).historyRecord(at: now) == nil)
    }

    @Test("Time at the Mac adds up, with no record")
    func timeAtMac() {
        #expect(day.applying(.atMac(seconds: 5)).applying(.atMac(seconds: 5)).secondsAtMac == 10)
        #expect(EngineEvent.atMac(seconds: 5).historyRecord(at: now) == nil)
    }

    @Test("Other events change nothing")
    func others() {
        for event in [EngineEvent.appStarted, .postureFixed, .milestone(.dailyGoal), .cameBack(awayFor: 60)] {
            #expect(day.applying(event) == day)
            #expect(event.historyRecord(at: now) == nil)
        }
    }
}
