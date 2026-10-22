import BuddyCore
import Foundation
import History
import Observation
import os

/// Keeps the history, the level and the form up to date from the engine's events.
///
///     EngineEvent ──▶ record (check, reminder) ──▶ history file
///                 └─▶ today's totals ──▶ ProgressState ──▶ milestones ──▶ onMilestone (the engine celebrates)
///
/// Time at the Mac arrives every 5 seconds, so today's totals are written at most once a minute
/// for it. Every other change is written at once. The rules live in BuddyCore (`Progression`).
@MainActor
@Observable
final class ProgressTracker {
    private(set) var state: ProgressState
    /// Change only when the level or form changes, so the island and menu bar do not redraw every tick.
    private(set) var level: Int
    private(set) var form: Int
    /// Set when the history file could not open or save. The Progress window shows it.
    private(set) var problem: String?

    /// Today's posture score from 0 to 100. Nil before the first known check.
    var todayScore: Int? { state.totals(on: Date(), calendar: calendar)?.score }

    @ObservationIgnored var onMilestone: (ProgressMilestone) -> Void = { _ in }
    @ObservationIgnored private let store: HistoryStore
    @ObservationIgnored private let calendar: Calendar
    /// Today's totals that changed since the last write.
    @ObservationIgnored private var unsaved: DayTotals?
    @ObservationIgnored private var lastWrite = Date.distantPast
    @ObservationIgnored private var lastCleanup: Date?

    static let atMacWriteInterval: TimeInterval = 60
    private static let logger = Logger(subsystem: "com.hassanarshad.axo", category: "Progress")

    init(store: HistoryStore, problem: String? = nil, calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
        self.problem = problem
        let days: [DayTotals]
        do {
            days = try store.allDays()
        } catch {
            days = []
            self.problem = Self.message("History could not be read", error)
        }
        let loaded = ProgressState(days: days)
        state = loaded
        level = loaded.level
        form = loaded.form
    }

    /// Opens the history file. When it cannot open, the history lives in memory for this session.
    static func openingFile() -> ProgressTracker {
        let url = SwiftDataHistoryStore.defaultURL
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            return ProgressTracker(store: try SwiftDataHistoryStore(url: url))
        } catch {
            let problem = message("History could not open, so today is not saved", error)
            return ProgressTracker(store: InMemoryHistoryStore(), problem: problem)
        }
    }

    func handle(_ event: EngineEvent, at date: Date = Date()) {
        cleanUpOnce(on: date)
        if let record = event.historyRecord(at: date) {
            write {
                switch record {
                case .check(let check): try store.add(check)
                case .reminder(let reminder): try store.add(reminder)
                }
            }
        }
        let before = state.totals(on: date, calendar: calendar) ?? .empty(on: date, calendar: calendar)
        let after = before.applying(event)
        guard after != before else { return }

        if let unsaved, unsaved.day != after.day {
            save(unsaved, at: date)  // The rest of yesterday, after midnight.
        }
        let next = state.updating(after)
        let milestones = Progression.milestones(from: state, to: next, at: date, calendar: calendar)
        state = next
        unsaved = after
        if case .atMac = event, date.timeIntervalSince(lastWrite) < Self.atMacWriteInterval {
            // Written with the next check, or within a minute.
        } else {
            save(after, at: date)
        }
        updateLevel()
        milestones.forEach(onMilestone)
    }

    /// Writes what is not written yet. Call when the app quits.
    func flush() {
        if let unsaved { save(unsaved, at: Date()) }
    }

    func deleteAll() {
        write { try store.deleteAll() }
        state = .empty
        unsaved = nil
        updateLevel()
    }

    private func save(_ totals: DayTotals, at date: Date) {
        write { try store.save(totals) }
        unsaved = nil
        lastWrite = date
    }

    private func updateLevel() {
        if level != state.level { level = state.level }
        if form != state.form { form = state.form }
    }

    /// Checks and reminder records older than 90 days go, once a day (`HistoryPolicy`).
    private func cleanUpOnce(on date: Date) {
        let today = calendar.startOfDay(for: date)
        guard lastCleanup != today else { return }
        lastCleanup = today
        write { try store.deleteRecords(before: HistoryPolicy.recordsCutoff(at: date, calendar: calendar)) }
    }

    private func write(_ action: () throws -> Void) {
        do {
            try action()
        } catch {
            problem = Self.message("History could not be saved", error)
        }
    }

    private static func message(_ text: String, _ error: Error) -> String {
        logger.error("\(text, privacy: .public): \(error.localizedDescription, privacy: .public)")
        return "\(text). \(error.localizedDescription)"
    }
}
