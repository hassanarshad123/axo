import BuddyCore
import SwiftUI

/// The editor for one reminder. Changes apply only on Save, cleaned by `ReminderRules`.
struct ReminderEditorView: View {
    let reminder: Reminder
    let isNew: Bool
    let onSave: (Reminder) -> Void
    let onDelete: (Reminder) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var message: String
    @State private var minutes: Int
    @State private var breakSeconds: Int
    @State private var timing: Reminder.Timing
    @State private var routineID: String?
    @State private var confirmDelete = false

    init(reminder: Reminder, isNew: Bool, onSave: @escaping (Reminder) -> Void, onDelete: @escaping (Reminder) -> Void)
    {
        self.reminder = reminder
        self.isNew = isNew
        self.onSave = onSave
        self.onDelete = onDelete
        _title = State(initialValue: reminder.title)
        _message = State(initialValue: reminder.message)
        _minutes = State(initialValue: Int(reminder.interval / 60))
        _breakSeconds = State(initialValue: Int(reminder.breakDuration))
        _timing = State(initialValue: reminder.timing)
        _routineID = State(initialValue: reminder.routineID)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    TextField("Title", text: $title, prompt: Text("Stand up"))
                    TextField("Message", text: $message, prompt: Text("What the buddy says"), axis: .vertical)
                        .lineLimit(2...4)
                    if title.count > ReminderRules.titleLimit || message.count > ReminderRules.messageLimit {
                        Text(
                            "Titles keep \(ReminderRules.titleLimit) characters, messages \(ReminderRules.messageLimit)."
                        )
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }
                Section {
                    Stepper(value: $minutes, in: ReminderRules.intervalMinutes) {
                        HStack {
                            Text("Every")
                            TextField("Minutes", value: $minutes, format: .number)
                                .frame(width: 48)
                                .multilineTextAlignment(.trailing)
                                .labelsHidden()
                            Text("min")
                        }
                    }
                    Picker("Counts", selection: $timing) {
                        Text("Only while I am at the Mac").tag(Reminder.Timing.activeUse)
                        Text("Real time, also when I am away").tag(Reminder.Timing.wallClock)
                    }
                }
                Section {
                    Picker("Break", selection: $breakSeconds) {
                        ForEach(BreakLength.choices(including: breakSeconds), id: \.self) { seconds in
                            Text(seconds == 0 ? "No break" : BreakLength.title(TimeInterval(seconds))).tag(seconds)
                        }
                    }
                    if breakSeconds > 0 {
                        Picker("Stretches", selection: $routineID) {
                            Text("Default (\(StretchRoutine.defaultRoutine(for: reminder.kind).title))")
                                .tag(String?.none)
                            ForEach(StretchRoutine.all) { routine in
                                Text(routine.title).tag(String?.some(routine.id))
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped)
            buttons
        }
        .frame(width: 440)
        .confirmationDialog("Delete \"\(reminder.title)\"?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                onDelete(reminder)
                dismiss()
            }
        }
    }

    private var buttons: some View {
        HStack {
            if reminder.kind == .custom, !isNew {
                Button("Delete…", role: .destructive) { confirmDelete = true }
            }
            Spacer()
            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(isNew ? "Add" : "Save") {
                onSave(edited)
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(16)
    }

    private var edited: Reminder {
        let changed = reminder.with(
            title: title,
            message: message,
            interval: TimeInterval(max(1, minutes) * 60),
            breakDuration: TimeInterval(max(0, breakSeconds)),
            timing: timing
        )
        return ReminderRules.cleaned(changed.withRoutine(routineID))
    }
}

/// Break lengths offered in the editor.
enum BreakLength {
    static let common = [0, 20, 30, 60, 90, 120, 180, 300, 600, 900]

    /// The common lengths, plus the saved one when it is not common.
    static func choices(including seconds: Int) -> [Int] {
        common.contains(seconds) ? common : (common + [seconds]).sorted()
    }

    /// "20 s", "1 min", "1.5 min", "2 min".
    static func title(_ seconds: TimeInterval) -> String {
        guard seconds >= 60 else { return "\(Int(seconds)) s" }
        let minutes = seconds / 60
        return minutes == minutes.rounded()
            ? "\(Int(minutes)) min" : "\(minutes.formatted(.number.precision(.fractionLength(1)))) min"
    }
}
