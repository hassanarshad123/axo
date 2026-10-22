import BuddyCore
import SwiftUI

/// The small window that opens from the menu bar icon.
struct MenuContentView: View {
    @Bindable var engine: BuddyEngine
    let updater: AppUpdater
    let openSetup: () -> Void
    let openProgress: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            nextReminders
            Divider()
            actions
        }
        .padding(14)
        .frame(width: 280)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(engine.appearance.name) · Level \(engine.progress.level)").font(.headline)
            Text(statusLine).font(.subheadline).foregroundStyle(.secondary)
            ForEach(problems, id: \.self) { problem in
                Text(problem).font(.caption).foregroundStyle(.orange)
            }
        }
    }

    /// Each sensor shows its own problem, and only while the user has that sensor turned on.
    private var problems: [String] {
        [
            engine.postureMonitor.calibrationMessage,
            engine.settings.cameraEnabled ? engine.postureMonitor.cameraError : nil,
            engine.settings.headphonesEnabled ? engine.postureMonitor.headphonesError : nil,
        ].compactMap { $0 }
    }

    private var statusLine: String {
        let score = engine.progress.todayScore.map { "Posture today: \($0)" } ?? "No posture data yet"
        switch engine.activity {
        case .active: return score
        case .inMeeting: return "In a call. Reminders wait. \(score)"
        case .away: return "You are away. \(score)"
        case .paused: return "Paused. \(score)"
        }
    }

    private var nextReminders: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(engine.schedule.reminders.filter(\.isEnabled)) { reminder in
                HStack {
                    Text(reminder.title)
                    Spacer()
                    Text(remainingText(for: reminder))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
            }
        }
    }

    private func remainingText(for reminder: Reminder) -> String {
        guard let seconds = engine.schedule.remaining(for: reminder.id) else { return "off" }
        return "in \(Int((seconds / 60).rounded(.up))) min"
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Pause buddy", isOn: $engine.isPausedByUser)
            Button("Stretch now") { engine.stretchNow() }
                .disabled(engine.breaks.isActive)
            Button(engine.settings.baseline == nil ? "Calibrate posture" : "Calibrate again") {
                Task { await engine.postureMonitor.calibrate() }
            }
            .disabled(engine.postureMonitor.isCalibrating)
            Button("Progress…", action: openProgress)
            Button("Setup guide…", action: openSetup)
            updateButton
            HStack {
                SettingsLink { Text("Settings…") }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
    }

    /// "Check for Updates…", or the version that the daily check found.
    @ViewBuilder private var updateButton: some View {
        if let version = updater.waitingVersion {
            Button("Install version \(version)…", action: updater.checkForUpdates)
                .foregroundStyle(Color.accentColor)
        } else {
            Button("Check for Updates…", action: updater.checkForUpdates)
        }
    }
}
