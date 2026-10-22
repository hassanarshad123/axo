import BuddyCore
import SwiftUI

/// Settings > Reminders: every reminder with its switch, an editor for each, and the break style.
struct RemindersSettingsView: View {
    let engine: BuddyEngine
    @Bindable var settings: SettingsStore
    /// The reminder in the editor. A new one is not in the list until Save.
    @State private var editing: Reminder?
    @State private var confirmReset = false

    var body: some View {
        Form {
            Section {
                ForEach(settings.reminders) { reminder in
                    row(reminder)
                }
            } footer: {
                HStack {
                    Button("Add a reminder") { editing = ReminderRules.newCustom() }
                        .disabled(!ReminderRules.canAdd(to: settings.reminders))
                    Spacer()
                    Button("Reset built-in reminders…") { confirmReset = true }
                }
            }
            Section("Breaks") {
                Picker("Break style", selection: $settings.strictness) {
                    ForEach(BreakStrictness.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                Text(styleHelp)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .sheet(item: $editing) { reminder in
            ReminderEditorView(
                reminder: reminder,
                isNew: !settings.reminders.contains { $0.id == reminder.id },
                onSave: save,
                onDelete: delete
            )
        }
        .confirmationDialog("Reset the built-in reminders?", isPresented: $confirmReset) {
            Button("Reset") { apply(ReminderRules.resettingBuiltIns(settings.reminders)) }
        } message: {
            Text("Stand up, eye rest, stretch and water go back to their first settings. Your own reminders stay.")
        }
    }

    private func row(_ reminder: Reminder) -> some View {
        HStack(spacing: 10) {
            Toggle(isOn: enabledBinding(for: reminder)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(reminder.title)
                    Text(ReminderSummary.text(for: reminder))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            Button("Edit") { editing = reminder }
        }
    }

    private var styleHelp: String {
        switch settings.strictness {
        case .gentle: "Breaks run in the notch. You start them with Done."
        case .fullScreenSkippable: "A break fills the screen 10 seconds after its notice. You can skip it."
        case .fullScreenLocked:
            "A break fills the screen 30 seconds after its notice and stays until it ends. "
                + "To leave early, hold Esc for 3 seconds. A call or a locked screen ends it."
        }
    }

    private func enabledBinding(for reminder: Reminder) -> Binding<Bool> {
        Binding(
            get: { reminder.isEnabled },
            set: { apply(ReminderRules.updating(reminder.with(isEnabled: $0), in: settings.reminders)) }
        )
    }

    private func save(_ reminder: Reminder) {
        let exists = settings.reminders.contains { $0.id == reminder.id }
        apply(
            exists
                ? ReminderRules.updating(reminder, in: settings.reminders)
                : ReminderRules.adding(reminder, to: settings.reminders))
    }

    private func delete(_ reminder: Reminder) {
        apply(ReminderRules.deleting(reminder.id, from: settings.reminders))
    }

    private func apply(_ reminders: [Reminder]) {
        guard reminders != settings.reminders else { return }
        settings.reminders = reminders
        engine.remindersChanged()
    }
}

/// One line about a reminder, for example "Every 30 min · 2 min break · Stand and move".
enum ReminderSummary {
    static func text(for reminder: Reminder) -> String {
        var parts = ["Every \(Int(reminder.interval / 60)) min"]
        if reminder.breakDuration > 0 {
            parts.append("\(BreakLength.title(reminder.breakDuration)) break")
            if reminder.routine != .timer { parts.append(reminder.routine.title) }
        }
        if reminder.timing == .wallClock { parts.append("real time") }
        return parts.joined(separator: " · ")
    }
}
