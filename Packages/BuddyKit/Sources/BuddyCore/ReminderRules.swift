import Foundation

/// The limits for a reminder, and changes to the reminder list. Each change returns a new list.
public enum ReminderRules {
    public static let titleLimit = 40
    public static let messageLimit = 140
    public static let maxReminders = 20
    /// 1 minute to 4 hours, in whole minutes.
    public static let intervalMinutes: ClosedRange<Int> = 1...240
    /// 0 (no break) to 15 minutes, in whole seconds.
    public static let breakSeconds: ClosedRange<Int> = 0...(15 * 60)

    /// The reminder inside the limits: text trimmed and cut, times rounded and clamped, unknown routine dropped.
    public static func cleaned(_ reminder: Reminder) -> Reminder {
        let title = cut(reminder.title, to: titleLimit)
        let minutes = clamp(Int((reminder.interval / 60).rounded()), to: intervalMinutes)
        let breakLength = clamp(Int(reminder.breakDuration.rounded()), to: breakSeconds)
        let routine = StretchRoutine.routine(id: reminder.routineID)?.id
        return Reminder(
            id: reminder.id,
            kind: reminder.kind,
            title: title.isEmpty ? defaultTitle(for: reminder.kind) : title,
            message: cut(reminder.message, to: messageLimit),
            interval: TimeInterval(minutes * 60),
            breakDuration: TimeInterval(breakLength),
            timing: reminder.timing,
            isEnabled: reminder.isEnabled,
            routineID: routine
        )
    }

    /// A new reminder of the user's own, ready to edit.
    public static func newCustom(id: UUID = UUID()) -> Reminder {
        Reminder(
            id: id, kind: .custom, title: "My reminder", message: "Time for a short pause.", interval: 45 * 60)
    }

    public static func canAdd(to list: [Reminder]) -> Bool {
        list.count < maxReminders
    }

    /// Adds the reminder at the end. A full list, or an id that is already there, changes nothing.
    public static func adding(_ reminder: Reminder, to list: [Reminder]) -> [Reminder] {
        guard canAdd(to: list), !list.contains(where: { $0.id == reminder.id }) else { return list }
        return list + [cleaned(reminder)]
    }

    /// Replaces the reminder with the same id, in the same place. The kind never changes.
    public static func updating(_ reminder: Reminder, in list: [Reminder]) -> [Reminder] {
        list.map { old in
            guard old.id == reminder.id, old.kind == reminder.kind else { return old }
            return cleaned(reminder)
        }
    }

    /// Removes a custom reminder. Built-in reminders can only be turned off.
    public static func deleting(_ id: Reminder.ID, from list: [Reminder]) -> [Reminder] {
        list.filter { $0.id != id || $0.kind != .custom }
    }

    /// The built-in reminders with their default settings, in the default order, then the custom ones.
    /// A built-in reminder keeps its id, so the schedule keeps its progress.
    public static func resettingBuiltIns(_ list: [Reminder]) -> [Reminder] {
        let builtIns = Reminder.defaults.map { fresh in
            guard let old = list.first(where: { $0.kind == fresh.kind }) else { return fresh }
            return Reminder(
                id: old.id, kind: fresh.kind, title: fresh.title, message: fresh.message, interval: fresh.interval,
                breakDuration: fresh.breakDuration, timing: fresh.timing, isEnabled: fresh.isEnabled)
        }
        return builtIns + list.filter { $0.kind == .custom }
    }

    static func defaultTitle(for kind: Reminder.Kind) -> String {
        Reminder.defaults.first { $0.kind == kind }?.title ?? "Reminder"
    }

    private static func cut(_ text: String, to limit: Int) -> String {
        String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(limit))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
