import Foundation

/// One thing the history keeps.
public enum HistoryRecord: Sendable, Equatable {
    case check(PostureCheckRecord)
    case reminder(ReminderRecord)

    public var reminderOutcome: ReminderRecord.Outcome? {
        if case .reminder(let record) = self { return record.outcome }
        return nil
    }
}

extension EngineEvent {
    /// The record the history keeps for this event. Nil for events it does not keep.
    public func historyRecord(at date: Date) -> HistoryRecord? {
        switch self {
        case .postureChecked(let assessment, let sensor):
            .check(PostureCheckRecord(date: date, assessment: assessment, sensor: sensor))
        case .reminderDue(let reminder):
            .reminder(ReminderRecord(date: date, kind: reminder.kind, outcome: .shown))
        case .reminderDone(let reminder):
            .reminder(ReminderRecord(date: date, kind: reminder.kind, outcome: .done))
        case .reminderSnoozed(let reminder):
            .reminder(ReminderRecord(date: date, kind: reminder.kind, outcome: .snoozed))
        case .breakEnded(let session, let outcome):
            .reminder(ReminderRecord(date: date, kind: session.kind, outcome: .init(outcome)))
        case .appStarted, .cameBack, .breakStarted, .postureNudged, .postureFixed, .atMac, .milestone,
            .calibrationStarted, .calibrationEnded, .setupFinished, .buddyPicked:
            nil
        }
    }
}

extension DayTotals {
    /// The day after this event: checks, done reminders, finished breaks and time at the Mac count.
    public func applying(_ event: EngineEvent) -> DayTotals {
        switch event {
        case .postureChecked(let assessment, _): recording(assessment)
        case .reminderDone: recordingReminderDone()
        case .breakEnded(_, .finished): recordingBreakFinished()
        case .atMac(let seconds): addingTimeAtMac(seconds)
        default: self
        }
    }
}
