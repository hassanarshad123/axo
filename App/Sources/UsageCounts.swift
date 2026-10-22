import BuddyCore
import Foundation
import NotchUI
import Observation
import os

/// Sends anonymous usage counts to TelemetryDeck (docs/PRIVACY.md, rule 8).
///
///     EngineEvent ─▶ UsageSignal (6 events only) ─▶ UsagePolicy ─▶ UsageReport ─▶ POST nom.telemetrydeck.com/v2/
///                                                   app id? setup done? switch on?
///
/// Axo sends the counts itself, without the TelemetryDeck SDK, so only the fields in
/// `UsageReport` leave the Mac (docs/DECISIONS.md T51). A count that cannot go waits in memory
/// and goes with the next one. Waiting counts are dropped when Axo quits or the switch goes off.
@MainActor
final class UsageCounts {
    /// The Info.plist key that holds the TelemetryDeck app id (`TELEMETRYDECK_APP_ID` in project.yml).
    static let appIDKey = "AxoTelemetryAppID"
    /// The random install id. Deleted when the user turns the counts off.
    static let installIDKey = "Axo.usageInstallID"
    private static let maxWaiting = 50
    private static let logger = Logger(subsystem: "com.hassanarshad.axo", category: "UsageCounts")

    private let settings: SettingsStore
    private let defaults: UserDefaults
    private let appID: String?
    private let sessionID = UUID().uuidString
    private let bundle: Bundle
    /// No cookies, no cache, no saved credentials.
    private let session = URLSession(configuration: .ephemeral)
    private var waiting: [UsageReport] = []
    private var isSending = false

    init(settings: SettingsStore, bundle: Bundle = .main, defaults: UserDefaults = .standard) {
        self.settings = settings
        self.bundle = bundle
        self.defaults = defaults
        appID = bundle.object(forInfoDictionaryKey: Self.appIDKey) as? String
        watchSwitch()
    }

    func handle(_ event: EngineEvent) {
        guard let signal = UsageSignal(event)?.hidingBuddy(unlessIn: BuddySprites.shared.openBuddyIDs), let appID,
            UsagePolicy.canSend(
                appID: appID, setupFinished: settings.hasFinishedOnboarding, enabled: settings.usageCountsEnabled)
        else { return }
        let report = UsageReport(signal: signal, context: context(appID: appID), at: .now)
        waiting = Array((waiting + [report]).suffix(Self.maxWaiting))
        sendWaiting()
    }

    private func sendWaiting() {
        guard !isSending, !waiting.isEmpty else { return }
        let batch = waiting
        isSending = true
        Task {
            let sent = await post(batch)
            isSending = false
            guard sent else { return }
            waiting = waiting.filter { !batch.contains($0) }
            sendWaiting()  // Counts that came in while this request ran.
        }
    }

    private func post(_ batch: [UsageReport]) async -> Bool {
        do {
            var request = URLRequest(url: UsageReport.endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try UsageReport.encode(batch)
            let (_, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard (200..<300).contains(status) else {
                Self.logger.error("Usage counts not accepted: HTTP \(status).")
                return false
            }
            return true
        } catch {
            Self.logger.error("Usage counts not sent: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func context(appID: String) -> UsageContext {
        let system = ProcessInfo.processInfo.operatingSystemVersion
        return UsageContext(
            appID: appID.trimmingCharacters(in: .whitespacesAndNewlines),
            installID: installID(),
            sessionID: sessionID,
            appVersion: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "",
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "",
            systemVersion: "\(system.majorVersion).\(system.minorVersion)",
            architecture: Self.architecture,
            isTestBuild: Self.isTestBuild)
    }

    private func installID() -> String {
        if let existing = defaults.string(forKey: Self.installIDKey) { return existing }
        let made = UUID().uuidString
        defaults.set(made, forKey: Self.installIDKey)
        return made
    }

    /// When the user turns "Share anonymous usage counts" off: drop the waiting counts and
    /// delete the install id. If the counts go on again, a new id is made.
    private func watchSwitch() {
        withObservationTracking {
            _ = settings.usageCountsEnabled
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if !self.settings.usageCountsEnabled {
                    self.waiting = []
                    self.defaults.removeObject(forKey: Self.installIDKey)
                    Self.logger.info("Usage counts off. Waiting counts and the install id deleted.")
                }
                self.watchSwitch()
            }
        }
    }

    #if arch(arm64)
        private static let architecture = "arm64"
    #else
        private static let architecture = "x86_64"
    #endif

    #if DEBUG
        private static let isTestBuild = true
    #else
        private static let isTestBuild = false
    #endif
}
