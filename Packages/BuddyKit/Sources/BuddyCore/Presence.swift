import Foundation

/// Is the user still at the Mac while they read or watch, with no keyboard or mouse input?
///
///     input ── 100 s idle ──▶ camera looks for a face or a person (3 s at most)
///                              ├─ seen: still here (active). Look again in 60 s.
///                              └─ nobody: away. No more looks until the next input.
///
/// Without this, 2 minutes of reading counts as away and the sitting timers reset.
/// A value type: each change returns a new value.
public struct Presence: Sendable, Equatable {
    /// Idle seconds before the first look. Before 120 s, when idle time alone makes the user away.
    public static let lookAfterIdle: TimeInterval = 100
    public static let lookAgainAfter: TimeInterval = 60
    /// The longest one look may run. It ends at the first face or person.
    public static let lookDuration: TimeInterval = 3
    /// How long a "seen" result counts. A bit more than the time to the next look.
    public static let seenValidFor: TimeInterval = 90

    /// The time of the last look, nil before the first one.
    public let lastLook: Date?
    /// What the last look found.
    public let lastLookSawPerson: Bool

    public init(lastLook: Date?, lastLookSawPerson: Bool) {
        self.lastLook = lastLook
        self.lastLookSawPerson = lastLookSawPerson
    }

    public static let unknown = Presence(lastLook: nil, lastLookSawPerson: false)

    /// True while the last look found the user and is recent.
    public func isPresent(at now: Date) -> Bool {
        guard let lastLook, lastLookSawPerson else { return false }
        return now.timeIntervalSince(lastLook) < Self.seenValidFor
    }

    /// `cameraAllowed`: the camera is on, calibrated, permitted, and the screen is unlocked.
    public func shouldLook(at now: Date, idleSeconds: TimeInterval, cameraAllowed: Bool) -> Bool {
        guard cameraAllowed, idleSeconds >= Self.lookAfterIdle else { return false }
        guard let lastLook else { return true }
        return lastLookSawPerson && now.timeIntervalSince(lastLook) >= Self.lookAgainAfter
    }

    public func recording(seen: Bool, at date: Date) -> Presence {
        Presence(lastLook: date, lastLookSawPerson: seen)
    }

    /// New input starts fresh: the next long idle gets its own looks.
    public func updated(idleSeconds: TimeInterval) -> Presence {
        idleSeconds < Self.lookAfterIdle ? .unknown : self
    }
}
