import BuddyCore
import Foundation
import Testing

@testable import History

private let start = Date(timeIntervalSince1970: 1_792_000_000)

private func minutes(_ count: Double) -> Date {
    start.addingTimeInterval(count * 60)
}

@MainActor
@Suite("SwiftData history store")
struct SwiftDataHistoryStoreTests {
    let store: SwiftDataHistoryStore

    init() throws {
        store = try SwiftDataHistoryStore(url: nil)
    }

    @Test("Checks come back in time order, with issues and sensor")
    func checks() throws {
        try store.add(PostureCheckRecord(date: minutes(2), assessment: .good, sensor: .camera))
        try store.add(
            PostureCheckRecord(
                date: minutes(1), assessment: .slouching([.headDropped, .leaningIn]), sensor: .headphones))
        try store.add(PostureCheckRecord(date: minutes(3), assessment: .unknown, sensor: nil))

        let saved = try store.checks(in: minutes(0)..<minutes(3))
        #expect(saved.map(\.date) == [minutes(1), minutes(2)])  // the range end is left out
        #expect(saved.first?.assessment == .slouching([.headDropped, .leaningIn]))
        #expect(saved.first?.sensor == .headphones)
        #expect(try store.checks(in: minutes(3)..<minutes(4)).first?.sensor == nil)
    }

    @Test("Reminder records keep their kind and outcome")
    func reminders() throws {
        try store.add(ReminderRecord(date: minutes(1), kind: .stretch, outcome: .shown))
        try store.add(ReminderRecord(date: minutes(2), kind: .stretch, outcome: .init(.finished)))
        let saved = try store.reminders(in: minutes(0)..<minutes(10))
        #expect(saved.map(\.outcome) == [.shown, .breakFinished])
        #expect(saved.allSatisfy { $0.kind == .stretch })
    }

    @Test("Saving a day twice keeps one day with the newest totals")
    func upsert() throws {
        try store.save(DayTotals(day: start, goodChecks: 1, knownChecks: 2))
        try store.save(DayTotals(day: start, goodChecks: 12, knownChecks: 14, secondsAtMac: 600, goalReached: true))
        try store.save(DayTotals(day: start.addingTimeInterval(-86_400), goodChecks: 3, knownChecks: 3))
        let days = try store.allDays()
        #expect(days.count == 2)
        #expect(
            days.last == DayTotals(day: start, goodChecks: 12, knownChecks: 14, secondsAtMac: 600, goalReached: true))
    }

    @Test("Old records are deleted, day totals stay")
    func deleteRecords() throws {
        try store.add(PostureCheckRecord(date: minutes(1), assessment: .good, sensor: .camera))
        try store.add(PostureCheckRecord(date: minutes(5), assessment: .good, sensor: .camera))
        try store.add(ReminderRecord(date: minutes(1), kind: .eyeRest, outcome: .done))
        try store.save(DayTotals(day: start, goodChecks: 2, knownChecks: 2))
        try store.deleteRecords(before: minutes(2))
        #expect(try store.checks(in: minutes(0)..<minutes(10)).map(\.date) == [minutes(5)])
        #expect(try store.reminders(in: minutes(0)..<minutes(10)).isEmpty)
        #expect(try store.allDays().count == 1)
    }

    @Test("Delete all empties the store")
    func deleteAll() throws {
        try store.add(PostureCheckRecord(date: minutes(1), assessment: .good, sensor: .camera))
        try store.save(DayTotals(day: start, goodChecks: 1, knownChecks: 1))
        try store.deleteAll()
        #expect(try store.allDays().isEmpty)
        #expect(try store.checks(in: minutes(0)..<minutes(10)).isEmpty)
    }

    @Test("A saved file opens again with the same history")
    func reopens() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appending(path: "History.store")

        try SwiftDataHistoryStore(url: url).save(DayTotals(day: start, goodChecks: 4, knownChecks: 5))
        #expect(try SwiftDataHistoryStore(url: url).allDays().map(\.goodChecks) == [4])
    }

    @Test("Text from a newer version reads as unknown, or the issue is left out")
    func unknownText() {
        #expect(SwiftDataHistoryStore.decode(result: "floating", issues: "") == .unknown)
        #expect(
            SwiftDataHistoryStore.decode(result: "slouching", issues: "leaningIn,newIssue") == .slouching([.leaningIn]))
        let (result, issues) = SwiftDataHistoryStore.encode(.slouching([.headTiltedDown]))
        #expect(SwiftDataHistoryStore.decode(result: result, issues: issues) == .slouching([.headTiltedDown]))
    }
}
