import BuddyCore
import Foundation

/// Keeps the user "at the Mac" while they read with no input, by a short camera look each minute.
/// The rules live in `Presence` (BuddyCore). This class only starts the looks and keeps the result.
@MainActor
final class PresenceWatcher {
    private(set) var presence = Presence.unknown
    private var isLooking = false
    private let look: @MainActor () async -> Bool?

    /// `look` returns true when the camera saw a person, nil when it could not look.
    init(look: @escaping @MainActor () async -> Bool?) {
        self.look = look
    }

    func isPresent(at date: Date = Date()) -> Bool {
        presence.isPresent(at: date)
    }

    /// Call each tick. Input starts fresh. A look starts when the rules say so.
    func update(idleSeconds: TimeInterval, cameraAllowed: Bool, at date: Date = Date()) {
        presence = presence.updated(idleSeconds: idleSeconds)
        guard !isLooking, presence.shouldLook(at: date, idleSeconds: idleSeconds, cameraAllowed: cameraAllowed)
        else { return }
        isLooking = true
        Task {
            let seen = await look()
            isLooking = false
            // A camera that could not look counts as "nobody": no retry until the next input.
            presence = presence.recording(seen: seen ?? false, at: Date())
        }
    }
}
