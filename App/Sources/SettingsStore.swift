import BuddyCore
import Foundation
import Observation
import os

/// User settings, saved in UserDefaults as JSON. Only this Mac, no cloud.
/// The saved format and its rules (missing or broken fields) live in `SettingsSnapshot`.
@MainActor
@Observable
final class SettingsStore {
    /// A new key for the Axo name. Settings saved as "PersonalBuddy.settings.v1" are not moved (pre-release).
    private static let storageKey = "Axo.settings.v1"
    private static let logger = Logger(subsystem: "com.hassanarshad.axo", category: "Settings")

    var reminders: [Reminder] { didSet { save() } }
    var cameraEnabled: Bool { didSet { save() } }
    var headphonesEnabled: Bool { didSet { save() } }
    var notificationsEnabled: Bool { didSet { save() } }
    var soundEnabled: Bool { didSet { save() } }
    var voiceEnabled: Bool { didSet { save() } }
    var voiceVolume: Double { didSet { save() } }
    var usageCountsEnabled: Bool { didSet { save() } }
    var strictness: BreakStrictness { didSet { save() } }
    /// Opt-in progress photos. Off by default (see docs/PRIVACY.md).
    var snapshotsEnabled: Bool { didSet { save() } }
    /// The good posture in use now. Learning moves it a little after good checks.
    var baseline: PostureBaseline? {
        didSet {
            if baseline != oldValue { save() }
        }
    }
    /// The good posture from the last calibration. Learning stays close to it. Set by `calibrate(_:)`.
    private(set) var calibratedBaseline: PostureBaseline?
    /// The picked buddy (a `Buddy.id`). An id that is not in the catalog shows Axo.
    var buddyID: String { didSet { save() } }
    /// The user's name for each buddy (buddy id → name). No entry = the buddy's own name. Cut to 16 characters when saved.
    var buddyNames: [String: String] { didSet { save() } }
    var buddyColor: BuddyColor { didSet { save() } }
    var menuBarIcon: MenuBarIconStyle { didSet { save() } }
    /// False until the user finishes the first-start window.
    var hasFinishedOnboarding: Bool { didSet { save() } }
    /// The camera the user picked. Nil = the built-in camera.
    var cameraID: String? { didSet { save() } }
    var sensitivity: PostureSensitivity { didSet { save() } }
    /// Codes that opened a locked buddy pack. The app opens those packs again at each start.
    var unlockCodes: [UnlockCode] { didSet { save() } }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = Self.load(from: defaults)
        reminders = stored.reminders
        cameraEnabled = stored.cameraEnabled
        headphonesEnabled = stored.headphonesEnabled
        notificationsEnabled = stored.notificationsEnabled
        soundEnabled = stored.soundEnabled
        voiceEnabled = stored.voiceEnabled
        voiceVolume = stored.voiceVolume
        usageCountsEnabled = stored.usageCountsEnabled
        strictness = stored.strictness
        snapshotsEnabled = stored.snapshotsEnabled
        baseline = stored.baseline
        calibratedBaseline = stored.calibratedBaseline
        buddyID = stored.buddyID
        buddyNames = stored.buddyNames
        buddyColor = stored.buddyColor
        menuBarIcon = stored.menuBarIcon
        hasFinishedOnboarding = stored.hasFinishedOnboarding
        cameraID = stored.cameraID
        sensitivity = stored.sensitivity
        unlockCodes = stored.unlockCodes
    }

    /// A new calibration: the posture in use and the anchor both start from it.
    func calibrate(_ newBaseline: PostureBaseline) {
        calibratedBaseline = newBaseline
        if baseline == newBaseline {
            save()  // `baseline` does not change, so its didSet will not save the new anchor.
        } else {
            baseline = newBaseline
        }
    }

    private static func load(from defaults: UserDefaults) -> SettingsSnapshot {
        guard let data = defaults.data(forKey: storageKey) else { return SettingsSnapshot() }
        do {
            return try JSONDecoder().decode(SettingsSnapshot.self, from: data)
        } catch {
            let reason = error.localizedDescription
            logger.error("Saved settings are unreadable; using defaults. \(reason, privacy: .public)")
            return SettingsSnapshot()
        }
    }

    private func save() {
        let snapshot = SettingsSnapshot(
            reminders: reminders,
            cameraEnabled: cameraEnabled,
            headphonesEnabled: headphonesEnabled,
            notificationsEnabled: notificationsEnabled,
            soundEnabled: soundEnabled,
            voiceEnabled: voiceEnabled,
            voiceVolume: voiceVolume,
            usageCountsEnabled: usageCountsEnabled,
            strictness: strictness,
            snapshotsEnabled: snapshotsEnabled,
            baseline: baseline,
            calibratedBaseline: calibratedBaseline,
            buddyID: buddyID,
            buddyNames: buddyNames,
            buddyColor: buddyColor,
            menuBarIcon: menuBarIcon,
            hasFinishedOnboarding: hasFinishedOnboarding,
            cameraID: cameraID,
            sensitivity: sensitivity,
            unlockCodes: unlockCodes
        )
        do {
            defaults.set(try JSONEncoder().encode(snapshot), forKey: Self.storageKey)
        } catch {
            Self.logger.error("Could not save settings. \(error.localizedDescription, privacy: .public)")
        }
    }
}
