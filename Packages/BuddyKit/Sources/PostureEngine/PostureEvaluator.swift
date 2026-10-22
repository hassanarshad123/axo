import BuddyCore
import Foundation

/// Compares one reading with the baseline and says if the posture is good.
public struct PostureEvaluator: Sendable, Equatable {
    public struct Thresholds: Sendable, Equatable {
        /// Head height may drop this fraction below the baseline (0.15 = 15%).
        public let headDrop: Double
        /// Shoulder width may grow this fraction above the baseline (user leans in).
        public let leanIn: Double
        /// Shoulder line may tilt this many degrees more than the baseline.
        public let sideTiltDegrees: Double
        /// AirPods head pitch may drop this many degrees below the baseline.
        public let headPitchDegrees: Double
        /// Readings below this confidence give `.unknown`.
        public let minimumConfidence: Double

        public init(
            headDrop: Double = 0.15,
            leanIn: Double = 0.15,
            sideTiltDegrees: Double = 8,
            headPitchDegrees: Double = 15,
            minimumConfidence: Double = 0.5
        ) {
            self.headDrop = headDrop
            self.leanIn = leanIn
            self.sideTiltDegrees = sideTiltDegrees
            self.headPitchDegrees = headPitchDegrees
            self.minimumConfidence = minimumConfidence
        }

        public static let standard = Thresholds()

        /// The standard limits scaled for the user's sensitivity. The confidence limit does not change.
        public static func standard(for sensitivity: PostureSensitivity) -> Thresholds {
            let scale = sensitivity.limitScale
            let base = Thresholds.standard
            return Thresholds(
                headDrop: base.headDrop * scale,
                leanIn: base.leanIn * scale,
                sideTiltDegrees: base.sideTiltDegrees * scale,
                headPitchDegrees: base.headPitchDegrees * scale,
                minimumConfidence: base.minimumConfidence
            )
        }
    }

    public let thresholds: Thresholds

    public init(thresholds: Thresholds = .standard) {
        self.thresholds = thresholds
    }

    public func assess(_ reading: PostureReading, against baseline: PostureBaseline) -> PostureAssessment {
        guard reading.confidence >= thresholds.minimumConfidence else { return .unknown }

        let checks: [(PostureIssue, Bool?)] = [
            (
                .headDropped,
                compare(reading.headHeight, baseline.headHeight) { now, base in
                    now < base * (1 - thresholds.headDrop)
                }
            ),
            (
                .leaningIn,
                compare(reading.shoulderWidth, baseline.shoulderWidth) { now, base in
                    now > base * (1 + thresholds.leanIn)
                }
            ),
            (
                .leaningSideways,
                compare(reading.shoulderTilt, baseline.shoulderTilt) { now, base in
                    abs(now - base) > thresholds.sideTiltDegrees
                }
            ),
            (
                .headTiltedDown,
                compare(reading.headPitch, baseline.headPitch) { now, base in
                    now < base - thresholds.headPitchDegrees
                }
            ),
        ]

        let measured = checks.compactMap { issue, failed in failed.map { (issue, $0) } }
        guard !measured.isEmpty else { return .unknown }

        let issues = measured.filter(\.1).map(\.0)
        return issues.isEmpty ? .good : .slouching(issues)
    }

    /// Returns nil if either value is missing, so a missing sensor never counts as bad posture.
    private func compare(_ now: Double?, _ base: Double?, _ isBad: (Double, Double) -> Bool) -> Bool? {
        guard let now, let base else { return nil }
        return isBad(now, base)
    }
}
