import Foundation

/// One anonymous usage count (TelemetryDeck). Only the events listed in the privacy notice
/// become counts, and only with the kind of reminder or the buddy id (docs/PRIVACY-NOTICE.md).
/// Posture, presence, voice and progress events are never counted.
public struct UsageSignal: Sendable, Equatable {
    public let name: String
    public let parameters: [String: String]

    public init(name: String, parameters: [String: String] = [:]) {
        self.name = name
        self.parameters = parameters
    }

    /// Nil for every event that is not counted.
    public init?(_ event: EngineEvent) {
        switch event {
        case .appStarted:
            self.init(name: "App.started")
        case .reminderDone(let reminder):
            self.init(name: "Reminder.done", parameters: ["kind": reminder.kind.rawValue])
        case .reminderSnoozed(let reminder):
            self.init(name: "Reminder.snoozed", parameters: ["kind": reminder.kind.rawValue])
        case .breakEnded(let session, .finished):
            self.init(name: "Break.finished", parameters: ["kind": session.kind.rawValue])
        case .setupFinished(let buddyID):
            self.init(name: "Setup.finished", parameters: ["buddy": buddyID])
        case .buddyPicked(let buddyID):
            self.init(name: "Buddy.picked", parameters: ["buddy": buddyID])
        case .cameBack, .reminderDue, .breakStarted, .breakEnded, .postureChecked, .postureNudged, .postureFixed,
            .atMac, .milestone, .calibrationStarted, .calibrationEnded:
            return nil
        }
    }

    /// The buddy value for a buddy that does not ship open: one from a locked pack, or an unknown id.
    public static let lockedBuddy = "locked"

    /// This count with its buddy id replaced by "locked", unless the id is in `openIDs`.
    /// So a count never names a buddy from a locked pack (DECISIONS T54).
    public func hidingBuddy(unlessIn openIDs: Set<String>) -> UsageSignal {
        guard let id = parameters["buddy"], !openIDs.contains(id) else { return self }
        return UsageSignal(name: name, parameters: parameters.merging(["buddy": Self.lockedBuddy]) { $1 })
    }
}

/// When counts may be sent: the build has an app id, the user finished the setup window,
/// and the "Share anonymous usage counts" switch is on.
public enum UsagePolicy {
    public static func canSend(appID: String?, setupFinished: Bool, enabled: Bool) -> Bool {
        let id = appID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !id.isEmpty && setupFinished && enabled
    }
}
