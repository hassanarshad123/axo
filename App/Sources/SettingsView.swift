import BuddyCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    let engine: BuddyEngine
    @Bindable var settings: SettingsStore
    let updater: AppUpdater

    var body: some View {
        TabView {
            BuddySettingsView(engine: engine, settings: settings)
                .tabItem { Label("Buddy", systemImage: "face.smiling") }
            PostureSettingsView(engine: engine, settings: settings)
                .tabItem { Label("Posture", systemImage: "figure.stand") }
            RemindersSettingsView(engine: engine, settings: settings)
                .tabItem { Label("Reminders", systemImage: "bell") }
            GeneralSettings(settings: settings, voice: engine.voice, updater: updater)
                .tabItem { Label("General", systemImage: "gearshape") }
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(width: 560, height: 500)
    }
}

private struct GeneralSettings: View {
    @Bindable var settings: SettingsStore
    let voice: VoiceCoach
    @Bindable var updater: AppUpdater
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("Alerts") {
                Toggle("Notification banners", isOn: $settings.notificationsEnabled)
                Toggle("Sounds", isOn: $settings.soundEnabled)
            }
            voiceSection
            Section("System") {
                Toggle("Open at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.orange)
                }
            }
            networkSection
        }
        .formStyle(.grouped)
    }

    /// The only two things in Axo that use the internet (docs/PRIVACY.md, rules 7 and 8).
    private var networkSection: some View {
        Section {
            HStack {
                Toggle("Check for updates automatically", isOn: $updater.checksAutomatically)
                Spacer()
                Button("Check Now", action: updater.checkForUpdates)
            }
            Toggle("Share anonymous usage counts", isOn: $settings.usageCountsEnabled)
        } header: {
            Text("Updates and usage counts")
        } footer: {
            Text(
                "Axo checks for a new version once a day. Usage counts tell us which features people use, "
                    + "such as \"a stretch break was finished\". They never hold your name, pictures or posture. "
                    + "The privacy notice at axo.zensbot.com/privacy lists every detail.")
        }
    }

    private var voiceSection: some View {
        Section {
            Toggle("Voice coach", isOn: $settings.voiceEnabled)
            LabeledContent("Volume") {
                HStack {
                    Slider(
                        value: $settings.voiceVolume, in: 0...1,
                        onEditingChanged: { editing in if !editing { voice.playSample() } })
                    Button("Play") { voice.playSample() }
                }
            }
            .disabled(!settings.voiceEnabled)
        } header: {
            Text("Voice")
        } footer: {
            Text(
                "Your buddy says reminders, break moves and good news out loud. It stays quiet in calls "
                    + "and never listens to the microphone. With the voice off, a short sound plays instead.")
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = nil
        } catch {
            loginError = "Could not change: \(error.localizedDescription)"
        }
    }
}

private struct AboutView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Axo").font(.title2.bold())
            Text("A calm buddy in your notch for posture and breaks.")
                .foregroundStyle(.secondary)
            Text("Made by Hassan Arshad. Free forever.")
                .font(.callout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
