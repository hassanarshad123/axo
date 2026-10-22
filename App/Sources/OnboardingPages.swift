import AppKit
import BuddyCore
import NotchUI
import PostureEngine
import SwiftUI
import UserNotifications

/// System permissions as plain values, for the setup window.
enum Permissions {
    static func notificationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    static func requestNotifications() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func openSystemSettings(_ pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }

    static let cameraPane = "com.apple.preference.security?Privacy_Camera"
    static let notificationsPane = "com.apple.preference.notifications"
}

/// Camera and notification permissions, each with its own button and state.
struct PermissionsPage: View {
    @Bindable var settings: SettingsStore
    @State private var notifications = UNAuthorizationStatus.notDetermined
    @State private var cameraAllowed = CameraPostureSampler.isAuthorized
    @State private var cameraAsked = false

    var body: some View {
        VStack(spacing: 20) {
            PageTitle(
                OnboardingStep.permissions.title,
                text: "Axo asks for two things. You can change both later in System Settings.")
            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    row(
                        icon: "camera", title: "Camera",
                        detail: "For posture checks: 3 seconds a minute, checked on this Mac only.",
                        allowed: cameraAllowed, denied: cameraAsked && !cameraAllowed, allow: allowCamera,
                        pane: Permissions.cameraPane)
                    Toggle("Use the camera for posture checks", isOn: $settings.cameraEnabled)
                        .padding(.leading, 36)
                }
                .padding(8)
            }
            GroupBox {
                row(
                    icon: "bell.badge", title: "Notifications",
                    detail: "Banners for reminders and posture nudges.",
                    allowed: notifications == .authorized || notifications == .provisional,
                    denied: notifications == .denied, allow: allowNotifications,
                    pane: Permissions.notificationsPane
                )
                .padding(8)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 40)
        .task { notifications = await Permissions.notificationStatus() }
    }

    private func row(
        icon: String, title: String, detail: String, allowed: Bool, denied: Bool,
        allow: @escaping () -> Void, pane: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title2).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if allowed {
                Label("Allowed", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else if denied {
                Button("Open System Settings") { Permissions.openSystemSettings(pane) }
            } else {
                Button("Allow", action: allow)
            }
        }
    }

    private func allowCamera() {
        Task {
            cameraAllowed = await CameraPostureSampler.requestAccess()
            cameraAsked = true
        }
    }

    private func allowNotifications() {
        Task {
            _ = await Permissions.requestNotifications()
            notifications = await Permissions.notificationStatus()
        }
    }
}

/// "I can see you" check, then a 5-second calibration with a countdown.
struct CalibratePage: View {
    let engine: BuddyEngine
    @Bindable var settings: SettingsStore
    @State private var seen: Bool??
    @State private var isLooking = false
    @State private var secondsLeft: Int?

    private var monitor: PostureMonitor { engine.postureMonitor }
    private var isBusy: Bool { isLooking || secondsLeft != nil || monitor.isCalibrating }

    var body: some View {
        VStack(spacing: 14) {
            Image("onboarding-calibrate")
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 230)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)
            PageTitle(
                OnboardingStep.calibrate.title,
                text: "Sit the way you want to sit: back straight, shoulders down, screen at eye height. "
                    + "Axo learns this as your good posture.")
            if settings.cameraEnabled {
                HStack {
                    Button("Check the camera") { look() }.disabled(isBusy)
                    lookResult
                }
            }
            HStack {
                Button(settings.baseline == nil ? "Calibrate" : "Calibrate again") { calibrate() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isBusy)
                calibrationStatus
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 20)
    }

    @ViewBuilder private var lookResult: some View {
        if isLooking {
            ProgressView().controlSize(.small)
        } else if let seen {
            switch seen {
            case true?: Label("I can see you.", systemImage: "eye").foregroundStyle(.green)
            case false?: Text("I cannot see you. Face the screen, in good light.").foregroundStyle(.orange)
            case nil: Text("The camera did not answer. Check the camera permission.").foregroundStyle(.orange)
            }
        }
    }

    @ViewBuilder private var calibrationStatus: some View {
        if let secondsLeft {
            Text("Hold still… \(secondsLeft)").monospacedDigit()
        } else if let message = monitor.calibrationMessage {
            Text(message).foregroundStyle(.orange)
        } else if settings.baseline != nil {
            Label("Done. This is your good posture.", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }

    private func look() {
        isLooking = true
        Task {
            let result = await monitor.lookForPerson()
            seen = .some(result)
            isLooking = false
        }
    }

    private func calibrate() {
        Task {
            let run = Task { await monitor.calibrate() }
            for left in stride(from: Int(PostureMonitor.calibrationDuration), through: 1, by: -1) {
                secondsLeft = left
                try? await Task.sleep(for: .seconds(1))
            }
            await run.value
            secondsLeft = nil
        }
    }
}

/// The last page: the buddy cheers, a few lines say where things are, and the voice can go off.
struct DonePage: View {
    let appearance: BuddyAppearance
    @Bindable var settings: SettingsStore

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            BuddySpriteView(appearance: appearance, mood: .celebrating, height: 140)
            PageTitle(OnboardingStep.done.title, text: "\(appearance.name) is in your notch now.")
            VStack(alignment: .leading, spacing: 8) {
                Label("Reminders and nudges show in the notch.", systemImage: "rectangle.topthird.inset.filled")
                Label(
                    "Click the menu bar icon to pause, stretch or open Settings.",
                    systemImage: "menubar.arrow.up.rectangle")
                Label("Open this guide again from the menu.", systemImage: "questionmark.circle")
            }
            .font(.callout)
            Toggle("\(appearance.name) talks to you (voice coach)", isOn: $settings.voiceEnabled)
                .toggleStyle(.switch)
            Spacer()
        }
    }
}

/// The usage-count switch on the privacy page, so the user sees it before any count goes.
struct UsageCountsChoice: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        VStack(spacing: 4) {
            Toggle("Share anonymous usage counts", isOn: $settings.usageCountsEnabled)
                .toggleStyle(.switch)
            Text("Counts like \"a break was finished\". Never your name, pictures or posture.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
