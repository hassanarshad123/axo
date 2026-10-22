import Foundation

/// All user settings as one saved value (UserDefaults JSON, this Mac only).
///
/// Decoding never throws away good settings:
/// - A missing field (saved by an older version) gets its default.
/// - A broken field resets only that field.
/// - A broken reminder is dropped. If every saved reminder is broken, the defaults come back.
public struct SettingsSnapshot: Codable, Sendable, Equatable {
    public let reminders: [Reminder]
    public let cameraEnabled: Bool
    public let headphonesEnabled: Bool
    public let notificationsEnabled: Bool
    /// Short system sounds. With the voice coach on, they play only when a voice line cannot.
    public let soundEnabled: Bool
    /// The recorded voice coach (`VoiceLine`). On by default (docs/DECISIONS.md #51).
    public let voiceEnabled: Bool
    /// The voice coach volume, from 0 to 1.
    public let voiceVolume: Double
    /// Anonymous usage counts (TelemetryDeck). On by default (docs/PRIVACY.md rule 7).
    public let usageCountsEnabled: Bool
    public let strictness: BreakStrictness
    /// Opt-in progress photos. Off by default (docs/PRIVACY.md rule 3).
    public let snapshotsEnabled: Bool
    /// The good posture in use now. It learns slowly over time.
    public let baseline: PostureBaseline?
    /// The good posture from the last calibration. Learning stays close to it.
    public let calibratedBaseline: PostureBaseline?
    /// The picked buddy (a `Buddy.id`). An id that is not in the catalog shows Axo.
    public let buddyID: String
    /// The user's name for each buddy (buddy id → name), at most 16 characters each.
    /// A buddy with no entry shows its own name.
    public let buddyNames: [String: String]
    public let buddyColor: BuddyColor
    public let menuBarIcon: MenuBarIconStyle
    /// False until the user finishes the first-start window.
    public let hasFinishedOnboarding: Bool
    /// The camera the user picked (`CameraInfo.id`). Nil = the built-in camera.
    public let cameraID: String?
    public let sensitivity: PostureSensitivity
    /// Codes the user typed that opened a locked buddy pack. The app opens those packs again at each start.
    public let unlockCodes: [UnlockCode]

    public init(
        reminders: [Reminder] = Reminder.defaults,
        cameraEnabled: Bool = true,
        headphonesEnabled: Bool = true,
        notificationsEnabled: Bool = true,
        soundEnabled: Bool = true,
        voiceEnabled: Bool = true,
        voiceVolume: Double = 0.7,
        usageCountsEnabled: Bool = true,
        strictness: BreakStrictness = .gentle,
        snapshotsEnabled: Bool = false,
        baseline: PostureBaseline? = nil,
        calibratedBaseline: PostureBaseline? = nil,
        buddyID: String = BuddyCatalog.defaultBuddyID,
        buddyNames: [String: String] = [:],
        buddyColor: BuddyColor = .original,
        menuBarIcon: MenuBarIconStyle = .outline,
        hasFinishedOnboarding: Bool = false,
        cameraID: String? = nil,
        sensitivity: PostureSensitivity = .normal,
        unlockCodes: [UnlockCode] = []
    ) {
        self.reminders = reminders
        self.cameraEnabled = cameraEnabled
        self.headphonesEnabled = headphonesEnabled
        self.notificationsEnabled = notificationsEnabled
        self.soundEnabled = soundEnabled
        self.voiceEnabled = voiceEnabled
        self.voiceVolume = voiceVolume.isFinite ? min(max(voiceVolume, 0), 1) : 0.7
        self.usageCountsEnabled = usageCountsEnabled
        self.strictness = strictness
        self.snapshotsEnabled = snapshotsEnabled
        self.baseline = baseline
        self.calibratedBaseline = calibratedBaseline
        self.buddyID = buddyID
        self.buddyNames = buddyNames.compactMapValues { BuddyName.limited($0) }
        self.buddyColor = buddyColor
        self.menuBarIcon = menuBarIcon
        self.hasFinishedOnboarding = hasFinishedOnboarding
        self.cameraID = cameraID
        self.sensitivity = sensitivity
        self.unlockCodes = unlockCodes.reduce(into: []) { unique, code in
            if !unique.contains(code) { unique.append(code) }
        }
    }

    private enum CodingKeys: String, CodingKey {
        case reminders, cameraEnabled, headphonesEnabled, notificationsEnabled, soundEnabled
        case voiceEnabled, voiceVolume, usageCountsEnabled
        case strictness, snapshotsEnabled, baseline, calibratedBaseline
        case buddyID, buddyNames, buddyColor, menuBarIcon
        case hasFinishedOnboarding, cameraID, sensitivity, unlockCodes
    }

    /// Read only: versions before per-buddy names saved one name for the picked buddy.
    private enum OldKeys: String, CodingKey {
        case buddyName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = SettingsSnapshot()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? container.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        let baseline = try? container.decodeIfPresent(PostureBaseline.self, forKey: .baseline)
        let calibratedBaseline = try? container.decodeIfPresent(PostureBaseline.self, forKey: .calibratedBaseline)
        let buddyID = value(.buddyID, defaults.buddyID)
        self.init(
            reminders: Self.decodeReminders(from: container) ?? defaults.reminders,
            cameraEnabled: value(.cameraEnabled, defaults.cameraEnabled),
            headphonesEnabled: value(.headphonesEnabled, defaults.headphonesEnabled),
            notificationsEnabled: value(.notificationsEnabled, defaults.notificationsEnabled),
            soundEnabled: value(.soundEnabled, defaults.soundEnabled),
            voiceEnabled: value(.voiceEnabled, defaults.voiceEnabled),
            voiceVolume: value(.voiceVolume, defaults.voiceVolume),
            usageCountsEnabled: value(.usageCountsEnabled, defaults.usageCountsEnabled),
            strictness: value(.strictness, defaults.strictness),
            snapshotsEnabled: value(.snapshotsEnabled, defaults.snapshotsEnabled),
            baseline: baseline,
            // Settings from before the anchor existed: the current baseline is the best anchor we have.
            calibratedBaseline: calibratedBaseline ?? baseline,
            buddyID: buddyID,
            buddyNames: (try? container.decodeIfPresent([String: String].self, forKey: .buddyNames))
                ?? Self.decodeOldName(from: decoder, buddyID: buddyID),
            buddyColor: value(.buddyColor, defaults.buddyColor),
            menuBarIcon: value(.menuBarIcon, defaults.menuBarIcon),
            hasFinishedOnboarding: value(.hasFinishedOnboarding, defaults.hasFinishedOnboarding),
            cameraID: try? container.decodeIfPresent(String.self, forKey: .cameraID),
            sensitivity: value(.sensitivity, defaults.sensitivity),
            unlockCodes: ((try? container.decodeIfPresent([LossyCode].self, forKey: .unlockCodes)) ?? [])
                .compactMap(\.code)
        )
    }

    /// Decodes one saved code, or nil if it is not a code, so one bad entry does not lose the others.
    private struct LossyCode: Decodable {
        let code: UnlockCode?

        init(from decoder: Decoder) throws {
            code = try? UnlockCode(from: decoder)
        }
    }

    /// The one name an older version saved belongs to the buddy that was picked then.
    private static func decodeOldName(from decoder: Decoder, buddyID: String) -> [String: String] {
        let old = try? decoder.container(keyedBy: OldKeys.self).decodeIfPresent(String.self, forKey: .buddyName)
        return BuddyName.names([:], setting: old, for: buddyID)
    }

    /// Nil means "use the defaults": the list is missing, unreadable, or every reminder in it is broken.
    private static func decodeReminders(from container: KeyedDecodingContainer<CodingKeys>) -> [Reminder]? {
        guard let saved = try? container.decodeIfPresent([LossyReminder].self, forKey: .reminders) else {
            return nil
        }
        let valid = saved.compactMap(\.reminder)
        return valid.isEmpty && !saved.isEmpty ? nil : valid
    }

    /// Decodes one reminder, or nil if it is broken, so one bad reminder does not lose the others.
    private struct LossyReminder: Decodable {
        let reminder: Reminder?

        init(from decoder: Decoder) throws {
            reminder = try? Reminder(from: decoder)
        }
    }
}
