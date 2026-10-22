import BuddyCore
import CoreGraphics
import Foundation

/// Turns body joint points from the camera into posture numbers.
/// Points use Vision's normalized space: 0...1, origin at the bottom left.
public enum BodyPoseMetrics {
    public struct Joints: Sendable, Equatable {
        public let nose: CGPoint?
        public let leftShoulder: CGPoint?
        public let rightShoulder: CGPoint?

        public init(nose: CGPoint?, leftShoulder: CGPoint?, rightShoulder: CGPoint?) {
            self.nose = nose
            self.leftShoulder = leftShoulder
            self.rightShoulder = rightShoulder
        }
    }

    /// Returns nil when the shoulders are not visible, because every metric depends on them.
    public static func reading(
        from joints: Joints,
        confidence: Double,
        at timestamp: Date
    ) -> PostureReading? {
        guard let left = joints.leftShoulder, let right = joints.rightShoulder else { return nil }

        let width = hypot(right.x - left.x, right.y - left.y)
        guard width > 0.01 else { return nil }

        let midY = (left.y + right.y) / 2
        let headHeight = joints.nose.map { Double(($0.y - midY) / width) }

        // The camera image is mirrored, so "left" and "right" can swap. Use the absolute angle
        // of the line between the shoulders, folded into -90...90 degrees.
        let (dx, dy) = left.x <= right.x ? (right.x - left.x, right.y - left.y) : (left.x - right.x, left.y - right.y)
        let tilt = atan2(Double(dy), Double(dx)) * 180 / .pi

        return PostureReading(
            timestamp: timestamp,
            source: .camera,
            headHeight: headHeight,
            shoulderWidth: Double(width),
            shoulderTilt: tilt,
            confidence: confidence
        )
    }
}
