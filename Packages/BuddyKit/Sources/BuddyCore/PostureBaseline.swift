import Foundation

/// The user's "good posture", saved during calibration and slowly adjusted over time.
public struct PostureBaseline: Codable, Sendable, Equatable {
    /// How far learning may move the baseline away from the calibrated one.
    public struct DriftLimits: Sendable, Equatable {
        /// For head height and shoulder width: a fraction of the calibrated value (0.10 = 10%).
        public let relative: Double
        /// For shoulder tilt and AirPods head pitch: degrees.
        public let degrees: Double

        public init(relative: Double, degrees: Double) {
            self.relative = relative
            self.degrees = degrees
        }

        public static let standard = DriftLimits(relative: 0.10, degrees: 3)
    }

    /// One step per posture check (not per reading). 0.05 = 5% of the way to the check's mean.
    public static let defaultLearningRate = 0.05

    public let headHeight: Double?
    public let shoulderWidth: Double?
    public let shoulderTilt: Double?
    public let headPitch: Double?

    public init(headHeight: Double?, shoulderWidth: Double?, shoulderTilt: Double?, headPitch: Double?) {
        self.headHeight = headHeight
        self.shoulderWidth = shoulderWidth
        self.shoulderTilt = shoulderTilt
        self.headPitch = headPitch
    }

    /// True if the camera took part in the calibration.
    public var hasCameraValues: Bool { headHeight != nil || shoulderWidth != nil || shoulderTilt != nil }
    /// True if AirPods took part in the calibration.
    public var hasHeadphoneValues: Bool { headPitch != nil }

    /// Builds a baseline from the readings taken while the user sat straight.
    /// Returns nil if no reading was good enough.
    public static func calibrated(
        from readings: [PostureReading],
        minimumConfidence: Double = 0.5
    ) -> PostureBaseline? {
        let usable = readings.filter { $0.confidence >= minimumConfidence }
        guard !usable.isEmpty else { return nil }
        let baseline = PostureBaseline(
            headHeight: mean(usable.compactMap(\.headHeight)),
            shoulderWidth: mean(usable.compactMap(\.shoulderWidth)),
            shoulderTilt: mean(usable.compactMap(\.shoulderTilt)),
            headPitch: mean(usable.compactMap(\.headPitch))
        )
        return baseline.hasCameraValues || baseline.hasHeadphoneValues ? baseline : nil
    }

    /// Moves the baseline a small step toward one reading. `rate` is 0...1.
    public func adapted(toward reading: PostureReading, rate: Double) -> PostureBaseline {
        let step = min(max(rate, 0), 1)
        return PostureBaseline(
            headHeight: Self.blend(headHeight, reading.headHeight, step),
            shoulderWidth: Self.blend(shoulderWidth, reading.shoulderWidth, step),
            shoulderTilt: Self.blend(shoulderTilt, reading.shoulderTilt, step),
            headPitch: Self.blend(headPitch, reading.headPitch, step)
        )
    }

    /// "Learns over time", once per posture check:
    ///
    ///     baseline ──one step (rate) toward the mean of the check's good readings──▶ clamp near `anchor`
    ///
    /// - One step per check, so 75 AirPods readings do not move it more than 12 camera readings.
    /// - The clamp keeps it close to the calibrated `anchor`, so slow slouching cannot drag it down.
    /// - A value the baseline does not have stays missing; learning never invents one.
    public func learning(
        from goodReadings: [PostureReading],
        anchor: PostureBaseline,
        rate: Double = defaultLearningRate,
        limits: DriftLimits = .standard
    ) -> PostureBaseline {
        guard let target = Self.calibrated(from: goodReadings, minimumConfidence: 0) else { return self }
        let step = min(max(rate, 0), 1)
        let moved = PostureBaseline(
            headHeight: Self.step(headHeight, toward: target.headHeight, step),
            shoulderWidth: Self.step(shoulderWidth, toward: target.shoulderWidth, step),
            shoulderTilt: Self.step(shoulderTilt, toward: target.shoulderTilt, step),
            headPitch: Self.step(headPitch, toward: target.headPitch, step)
        )
        return moved.clamped(near: anchor, limits: limits)
    }

    /// Keeps every value within `limits` of the anchor's value.
    public func clamped(near anchor: PostureBaseline, limits: DriftLimits = .standard) -> PostureBaseline {
        PostureBaseline(
            headHeight: Self.clamp(headHeight, near: anchor.headHeight) { abs($0) * limits.relative },
            shoulderWidth: Self.clamp(shoulderWidth, near: anchor.shoulderWidth) { abs($0) * limits.relative },
            shoulderTilt: Self.clamp(shoulderTilt, near: anchor.shoulderTilt) { _ in limits.degrees },
            headPitch: Self.clamp(headPitch, near: anchor.headPitch) { _ in limits.degrees }
        )
    }

    private static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func blend(_ old: Double?, _ new: Double?, _ step: Double) -> Double? {
        switch (old, new) {
        case let (old?, new?): return old + (new - old) * step
        case let (old?, nil): return old
        case let (nil, new?): return new
        case (nil, nil): return nil
        }
    }

    private static func step(_ old: Double?, toward target: Double?, _ step: Double) -> Double? {
        guard let old else { return nil }
        guard let target else { return old }
        return old + (target - old) * step
    }

    private static func clamp(_ value: Double?, near anchor: Double?, margin: (Double) -> Double) -> Double? {
        guard let value, let anchor else { return value }
        let allowed = margin(anchor)
        return min(max(value, anchor - allowed), anchor + allowed)
    }
}
