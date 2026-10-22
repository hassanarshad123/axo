import Foundation

/// One repeating nudge from the buddy, for example "stand up every 30 minutes".
/// Users can edit the built-in reminders and add their own.
public struct Reminder: Identifiable, Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Sendable, CaseIterable {
        case standUp
        case stretch
        case eyeRest
        case drinkWater
        case custom
    }

    /// How the reminder counts time.
    public enum Timing: String, Codable, Sendable {
        /// Counts only while the user is at the Mac. A long enough away period
        /// (the user stood up) starts the count again.
        case activeUse
        /// Counts real time, also while the user is away. Due reminders wait
        /// until the user is back.
        case wallClock
    }

    public let id: UUID
    public let kind: Kind
    public let title: String
    /// What the buddy says when the reminder fires.
    public let message: String
    /// Seconds between two reminders.
    public let interval: TimeInterval
    /// Seconds the break itself lasts (0 = no timed break).
    public let breakDuration: TimeInterval
    public let timing: Timing
    public let isEnabled: Bool
    /// The stretch routine for the break (a `StretchRoutine.id`). Nil = the default for the kind.
    public let routineID: String?

    public init(
        id: UUID = UUID(),
        kind: Kind,
        title: String,
        message: String,
        interval: TimeInterval,
        breakDuration: TimeInterval = 0,
        timing: Timing = .activeUse,
        isEnabled: Bool = true,
        routineID: String? = nil
    ) {
        precondition(interval > 0, "A reminder interval must be greater than zero")
        precondition(breakDuration >= 0, "A break duration cannot be negative")
        self.id = id
        self.kind = kind
        self.title = title
        self.message = message
        self.interval = interval
        self.breakDuration = breakDuration
        self.timing = timing
        self.isEnabled = isEnabled
        self.routineID = routineID
    }

    public func with(
        title: String? = nil,
        message: String? = nil,
        interval: TimeInterval? = nil,
        breakDuration: TimeInterval? = nil,
        timing: Timing? = nil,
        isEnabled: Bool? = nil
    ) -> Reminder {
        Reminder(
            id: id,
            kind: kind,
            title: title ?? self.title,
            message: message ?? self.message,
            interval: interval ?? self.interval,
            breakDuration: breakDuration ?? self.breakDuration,
            timing: timing ?? self.timing,
            isEnabled: isEnabled ?? self.isEnabled,
            routineID: routineID
        )
    }

    /// A copy with another routine. Nil goes back to the default routine for the kind.
    public func withRoutine(_ routineID: String?) -> Reminder {
        Reminder(
            id: id, kind: kind, title: title, message: message, interval: interval,
            breakDuration: breakDuration, timing: timing, isEnabled: isEnabled, routineID: routineID)
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, title, message, interval, breakDuration, timing, isEnabled, routineID
    }

    /// Checks saved data the same way `init` does, but throws instead of crashing.
    /// A zero, negative or broken interval throws; a negative break length becomes 0.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let interval = try container.decode(TimeInterval.self, forKey: .interval)
        guard interval.isFinite, interval > 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .interval, in: container, debugDescription: "A reminder interval must be greater than zero")
        }
        let breakDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .breakDuration) ?? 0
        self.init(
            id: try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID(),
            kind: try container.decode(Kind.self, forKey: .kind),
            title: try container.decode(String.self, forKey: .title),
            message: try container.decode(String.self, forKey: .message),
            interval: interval,
            breakDuration: breakDuration.isFinite ? max(0, breakDuration) : 0,
            timing: try container.decodeIfPresent(Timing.self, forKey: .timing) ?? .activeUse,
            isEnabled: try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true,
            routineID: try? container.decodeIfPresent(String.self, forKey: .routineID)
        )
    }
}

public extension Reminder {
    /// The reminders a new user gets. All of them can be changed or turned off.
    static let defaults: [Reminder] = [
        Reminder(
            kind: .standUp,
            title: "Stand up",
            message: "You have been sitting for a while. Stand up and move a little.",
            interval: 30 * 60,
            breakDuration: 2 * 60
        ),
        Reminder(
            kind: .eyeRest,
            title: "Rest your eyes",
            message: "Look at something far away for 20 seconds.",
            interval: 20 * 60,
            breakDuration: 20
        ),
        Reminder(
            kind: .stretch,
            title: "Stretch",
            message: "Time for a slow neck and shoulder stretch.",
            interval: 60 * 60,
            breakDuration: 90
        ),
        Reminder(
            kind: .drinkWater,
            title: "Drink water",
            message: "Take a few sips of water.",
            interval: 60 * 60,
            timing: .wallClock
        ),
    ]
}
