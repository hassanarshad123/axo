import Foundation
import Testing

@testable import BuddyCore

@MainActor
@Suite("In-memory history store")
struct InMemoryHistoryStoreTests {
    private let start = Date(timeIntervalSince1970: 1_792_000_000)

    @Test("Saving a day twice keeps one day; days come back oldest first")
    func days() {
        let store = InMemoryHistoryStore()
        store.save(DayTotals(day: start, goodChecks: 1))
        store.save(DayTotals(day: start.addingTimeInterval(-86_400)))
        store.save(DayTotals(day: start, goodChecks: 5))
        #expect(store.allDays().map(\.goodChecks) == [0, 5])
    }

    @Test("Records in a range, and deleting old records keeps the days")
    func records() {
        let store = InMemoryHistoryStore()
        store.add(PostureCheckRecord(date: start.addingTimeInterval(60), assessment: .good, sensor: .camera))
        store.add(PostureCheckRecord(date: start, assessment: .unknown, sensor: nil))
        store.add(ReminderRecord(date: start, kind: .drinkWater, outcome: .done))
        store.save(DayTotals(day: start))
        let range = start..<start.addingTimeInterval(120)
        #expect(store.checks(in: range).map(\.date) == [start, start.addingTimeInterval(60)])
        store.deleteRecords(before: start.addingTimeInterval(30))
        #expect(store.checks(in: range).count == 1)
        #expect(store.reminders(in: range).isEmpty)
        #expect(store.allDays().count == 1)
    }

    @Test("Break outcomes map to reminder outcomes")
    func outcomes() {
        #expect(ReminderRecord.Outcome(.finished) == .breakFinished)
        #expect(ReminderRecord.Outcome(.skipped) == .breakSkipped)
        #expect(ReminderRecord.Outcome(.emergencyExit) == .breakExited)
        #expect(ReminderRecord.Outcome(.interrupted) == .breakInterrupted)
    }

    @Test("Records older than 90 days are cut off at the start of a day")
    func cutoff() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Karachi")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 22, hour: 15))!
        let cutoff = calendar.date(from: DateComponents(year: 2026, month: 7, day: 24))!
        #expect(HistoryPolicy.recordsCutoff(at: now, calendar: calendar) == cutoff)
    }
}
