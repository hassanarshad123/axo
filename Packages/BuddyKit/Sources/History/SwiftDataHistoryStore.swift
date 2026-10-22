import BuddyCore
import Foundation
import SwiftData

typealias PostureCheckEntry = HistorySchemaV1.PostureCheckEntry
typealias ReminderEntry = HistorySchemaV1.ReminderEntry
typealias DayEntry = HistorySchemaV1.DayEntry

/// The history in a SwiftData file on this Mac. Never synced: CloudKit is off (docs/PRIVACY.md rule 4).
///
///     ~/Library/Application Support/Axo/History.store
@MainActor
public final class SwiftDataHistoryStore: HistoryStore {
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    /// Opens (or makes) the store at `url`. Nil keeps it in memory, for tests.
    public init(url: URL?) throws {
        let schema = Schema(versionedSchema: HistorySchemaV1.self)
        let configuration =
            if let url {
                ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            } else {
                ModelConfiguration(
                    UUID().uuidString, schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            }
        container = try ModelContainer(
            for: schema, migrationPlan: HistoryMigrationPlan.self, configurations: configuration)
    }

    public static var defaultURL: URL {
        URL.applicationSupportDirectory.appending(path: "Axo/History.store")
    }

    public func add(_ record: PostureCheckRecord) throws {
        let (result, issues) = Self.encode(record.assessment)
        context.insert(
            PostureCheckEntry(date: record.date, result: result, issues: issues, sensor: record.sensor?.rawValue))
        try context.save()
    }

    public func add(_ record: ReminderRecord) throws {
        context.insert(ReminderEntry(date: record.date, kind: record.kind.rawValue, outcome: record.outcome.rawValue))
        try context.save()
    }

    public func save(_ totals: DayTotals) throws {
        let day = totals.day
        var descriptor = FetchDescriptor<DayEntry>(predicate: #Predicate { $0.day == day })
        descriptor.fetchLimit = 1
        if let entry = try context.fetch(descriptor).first {
            entry.goodChecks = totals.goodChecks
            entry.knownChecks = totals.knownChecks
            entry.breaksFinished = totals.breaksFinished
            entry.remindersDone = totals.remindersDone
            entry.secondsAtMac = totals.secondsAtMac
            entry.goalReached = totals.goalReached
        } else {
            context.insert(
                DayEntry(
                    day: day, goodChecks: totals.goodChecks, knownChecks: totals.knownChecks,
                    breaksFinished: totals.breaksFinished, remindersDone: totals.remindersDone,
                    secondsAtMac: totals.secondsAtMac, goalReached: totals.goalReached))
        }
        try context.save()
    }

    public func allDays() throws -> [DayTotals] {
        let descriptor = FetchDescriptor<DayEntry>(sortBy: [SortDescriptor(\.day)])
        return try context.fetch(descriptor).map { entry in
            DayTotals(
                day: entry.day, goodChecks: entry.goodChecks, knownChecks: entry.knownChecks,
                breaksFinished: entry.breaksFinished, remindersDone: entry.remindersDone,
                secondsAtMac: entry.secondsAtMac, goalReached: entry.goalReached)
        }
    }

    public func checks(in range: Range<Date>) throws -> [PostureCheckRecord] {
        let start = range.lowerBound
        let end = range.upperBound
        let descriptor = FetchDescriptor<PostureCheckEntry>(
            predicate: #Predicate { $0.date >= start && $0.date < end }, sortBy: [SortDescriptor(\.date)])
        return try context.fetch(descriptor).map { entry in
            PostureCheckRecord(
                date: entry.date,
                assessment: Self.decode(result: entry.result, issues: entry.issues),
                sensor: entry.sensor.flatMap(PostureReading.Source.init(rawValue:)))
        }
    }

    public func reminders(in range: Range<Date>) throws -> [ReminderRecord] {
        let start = range.lowerBound
        let end = range.upperBound
        let descriptor = FetchDescriptor<ReminderEntry>(
            predicate: #Predicate { $0.date >= start && $0.date < end }, sortBy: [SortDescriptor(\.date)])
        // A kind or outcome this version does not know (from a newer version) is left out.
        return try context.fetch(descriptor).compactMap { entry in
            guard let kind = Reminder.Kind(rawValue: entry.kind),
                let outcome = ReminderRecord.Outcome(rawValue: entry.outcome)
            else { return nil }
            return ReminderRecord(date: entry.date, kind: kind, outcome: outcome)
        }
    }

    public func deleteRecords(before date: Date) throws {
        try context.delete(model: PostureCheckEntry.self, where: #Predicate { $0.date < date })
        try context.delete(model: ReminderEntry.self, where: #Predicate { $0.date < date })
        try context.save()
    }

    public func deleteAll() throws {
        try context.delete(model: PostureCheckEntry.self)
        try context.delete(model: ReminderEntry.self)
        try context.delete(model: DayEntry.self)
        try context.save()
    }

    // MARK: - Posture results as text

    static func encode(_ assessment: PostureAssessment) -> (result: String, issues: String) {
        switch assessment {
        case .good: ("good", "")
        case .unknown: ("unknown", "")
        case .slouching(let issues): ("slouching", issues.map(\.rawValue).joined(separator: ","))
        }
    }

    /// Text this version does not know reads as unknown, or the issue is left out.
    static func decode(result: String, issues: String) -> PostureAssessment {
        switch result {
        case "good": .good
        case "slouching": .slouching(issues.split(separator: ",").compactMap { PostureIssue(rawValue: String($0)) })
        default: .unknown
        }
    }
}
