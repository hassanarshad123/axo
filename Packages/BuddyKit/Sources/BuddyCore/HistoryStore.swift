import Foundation

/// One posture check, as saved in the history. Only the result: never a picture or a measurement.
public struct PostureCheckRecord: Sendable, Equatable {
    public let date: Date
    public let assessment: PostureAssessment
    /// The sensor that decided the result. Nil when no sensor saw the user.
    public let sensor: PostureReading.Source?

    public init(date: Date, assessment: PostureAssessment, sensor: PostureReading.Source?) {
        self.date = date
        self.assessment = assessment
        self.sensor = sensor
    }
}

/// What happened to one reminder or its break, as saved in the history.
public struct ReminderRecord: Sendable, Equatable {
    public enum Outcome: String, Codable, Sendable, CaseIterable {
        case shown
        case done
        case snoozed
        case breakFinished
        case breakSkipped
        case breakExited
        case breakInterrupted

        public init(_ outcome: BreakOutcome) {
            switch outcome {
            case .finished: self = .breakFinished
            case .skipped: self = .breakSkipped
            case .emergencyExit: self = .breakExited
            case .interrupted: self = .breakInterrupted
            }
        }
    }

    public let date: Date
    public let kind: Reminder.Kind
    public let outcome: Outcome

    public init(date: Date, kind: Reminder.Kind, outcome: Outcome) {
        self.date = date
        self.kind = kind
        self.outcome = outcome
    }
}

/// How long the history keeps each check and reminder. Day totals stay, so the level and the
/// streak never go back; they are a few numbers a day.
public enum HistoryPolicy {
    public static let recordDays = 90

    /// Records before this date are deleted.
    public static func recordsCutoff(at date: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: -recordDays, to: today) ?? today
    }
}

/// Where the history lives. The app uses SwiftData (the `History` module); tests use `InMemoryHistoryStore`.
/// Everything stays on this Mac (docs/PRIVACY.md rule 4).
@MainActor
public protocol HistoryStore: AnyObject {
    func add(_ record: PostureCheckRecord) throws
    func add(_ record: ReminderRecord) throws
    /// Adds the day, or replaces the saved day with the same start.
    func save(_ totals: DayTotals) throws
    /// All saved days, oldest first.
    func allDays() throws -> [DayTotals]
    /// Checks in `range`, oldest first.
    func checks(in range: Range<Date>) throws -> [PostureCheckRecord]
    /// Reminder records in `range`, oldest first.
    func reminders(in range: Range<Date>) throws -> [ReminderRecord]
    /// Deletes checks and reminder records before `date`. Day totals stay.
    func deleteRecords(before date: Date) throws
    func deleteAll() throws
}

/// A history that lives only in memory. For tests, and for the app when the file store cannot open.
@MainActor
public final class InMemoryHistoryStore: HistoryStore {
    private var checkRecords: [PostureCheckRecord] = []
    private var reminderRecords: [ReminderRecord] = []
    private var days: [DayTotals] = []

    public init() {}

    public func add(_ record: PostureCheckRecord) {
        checkRecords = checkRecords + [record]
    }

    public func add(_ record: ReminderRecord) {
        reminderRecords = reminderRecords + [record]
    }

    public func save(_ totals: DayTotals) {
        days = days.filter { $0.day != totals.day } + [totals]
    }

    public func allDays() -> [DayTotals] {
        days.sorted { $0.day < $1.day }
    }

    public func checks(in range: Range<Date>) -> [PostureCheckRecord] {
        checkRecords.filter { range.contains($0.date) }.sorted { $0.date < $1.date }
    }

    public func reminders(in range: Range<Date>) -> [ReminderRecord] {
        reminderRecords.filter { range.contains($0.date) }.sorted { $0.date < $1.date }
    }

    public func deleteRecords(before date: Date) {
        checkRecords = checkRecords.filter { $0.date >= date }
        reminderRecords = reminderRecords.filter { $0.date >= date }
    }

    public func deleteAll() {
        checkRecords = []
        reminderRecords = []
        days = []
    }
}
