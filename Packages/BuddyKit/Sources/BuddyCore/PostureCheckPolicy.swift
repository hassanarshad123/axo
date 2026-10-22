import Foundation

/// Decides which sensors a posture check may use right now (docs/PRIVACY.md rules 2 and 5).
public enum PostureCheckPolicy {
    /// The camera runs only if the user touched the keyboard or mouse this recently.
    /// The user counts as `.active` for 2 minutes after the last input, which is too long for a camera.
    public static let maximumIdleForCamera: TimeInterval = 30

    public struct Sensors: Sendable, Equatable {
        public let camera: Bool
        public let headphones: Bool

        public init(camera: Bool, headphones: Bool) {
            self.camera = camera
            self.headphones = headphones
        }

        public var any: Bool { camera || headphones }

        public static let none = Sensors(camera: false, headphones: false)
    }

    public static func sensors(
        activity: ActivityState,
        idleSeconds: TimeInterval,
        isScreenLockedOrAsleep: Bool,
        cameraEnabled: Bool,
        headphonesEnabled: Bool,
        maximumIdleForCamera: TimeInterval = maximumIdleForCamera
    ) -> Sensors {
        guard activity == .active, !isScreenLockedOrAsleep else { return .none }
        return Sensors(
            camera: cameraEnabled && idleSeconds < maximumIdleForCamera,
            headphones: headphonesEnabled
        )
    }
}
