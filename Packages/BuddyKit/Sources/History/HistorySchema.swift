import Foundation
import SwiftData

/// The saved shape of the history, version 1. A later version adds a new schema enum and a
/// migration stage in `HistoryMigrationPlan`; never change a model here after release.
///
///     PostureCheckEntry   one a minute while checks run     kept 90 days
///     ReminderEntry       each shown, done, snoozed, break   kept 90 days
///     DayEntry            one a day (unique day)            kept
public enum HistorySchemaV1: VersionedSchema {
    public static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    public static var models: [any PersistentModel.Type] {
        [PostureCheckEntry.self, ReminderEntry.self, DayEntry.self]
    }

    @Model
    public final class PostureCheckEntry {
        public var date: Date
        /// "good", "slouching" or "unknown".
        public var result: String
        /// `PostureIssue` raw values joined with commas. Empty unless slouching.
        public var issues: String
        /// A `PostureReading.Source` raw value. Nil when no sensor saw the user.
        public var sensor: String?

        public init(date: Date, result: String, issues: String, sensor: String?) {
            self.date = date
            self.result = result
            self.issues = issues
            self.sensor = sensor
        }
    }

    @Model
    public final class ReminderEntry {
        public var date: Date
        /// A `Reminder.Kind` raw value.
        public var kind: String
        /// A `ReminderRecord.Outcome` raw value.
        public var outcome: String

        public init(date: Date, kind: String, outcome: String) {
            self.date = date
            self.kind = kind
            self.outcome = outcome
        }
    }

    @Model
    public final class DayEntry {
        @Attribute(.unique) public var day: Date
        public var goodChecks: Int
        public var knownChecks: Int
        public var breaksFinished: Int
        public var remindersDone: Int
        public var secondsAtMac: Double
        public var goalReached: Bool

        public init(
            day: Date, goodChecks: Int, knownChecks: Int, breaksFinished: Int, remindersDone: Int,
            secondsAtMac: Double, goalReached: Bool
        ) {
            self.day = day
            self.goodChecks = goodChecks
            self.knownChecks = knownChecks
            self.breaksFinished = breaksFinished
            self.remindersDone = remindersDone
            self.secondsAtMac = secondsAtMac
            self.goalReached = goalReached
        }
    }
}

/// Every schema version, oldest first, and the steps between them. Version 1 has no steps yet.
public enum HistoryMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [HistorySchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}
