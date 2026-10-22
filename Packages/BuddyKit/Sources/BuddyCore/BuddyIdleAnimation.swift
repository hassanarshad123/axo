import Foundation

/// The buddy's idle loop, as a pure function of time. Pixel style: whole steps, no easing.
///
///     bob:    0 ──── 1 pt up ──── 0 ──── 1 pt up        (each step `bobStep` s; a sleeping buddy is still)
///     blink:  open .............. shut ..............   (`blinkLength` s every `blinkEvery` s,
///                                                         calm only, only with blink art)
///
/// The blink art is the calm pose with closed eyes. In any other mood a blink would swap the whole pose
/// for one frame, so the buddy blinks only when calm (the mood it shows most of the day).
public struct BuddyIdleAnimation: Sendable, Equatable {
    public struct Frame: Sendable, Equatable {
        /// Points to move the buddy up.
        public let bobOffset: Double
        public let isBlinking: Bool

        public static let still = Frame(bobOffset: 0, isBlinking: false)
    }

    public let bobStep: TimeInterval
    public let bobHeight: Double
    public let blinkEvery: TimeInterval
    public let blinkLength: TimeInterval

    public init(
        bobStep: TimeInterval = 0.8,
        bobHeight: Double = 1,
        blinkEvery: TimeInterval = 4,
        blinkLength: TimeInterval = 0.15
    ) {
        self.bobStep = max(0.05, bobStep)
        self.bobHeight = bobHeight
        self.blinkEvery = max(0.1, blinkEvery)
        self.blinkLength = min(max(0, blinkLength), self.blinkEvery / 2)
    }

    /// - Parameter time: any clock in seconds, for example `Date.timeIntervalSinceReferenceDate`.
    /// - Parameter canBlink: true only when this buddy has blink art.
    public func frame(at time: TimeInterval, mood: BuddyMood, canBlink: Bool) -> Frame {
        let isUp = Int((time / bobStep).rounded(.down)) % 2 != 0
        let bob = mood != .sleeping && isUp ? bobHeight : 0
        let blinks = canBlink && mood == .calm
        return Frame(bobOffset: bob, isBlinking: blinks && Self.remainder(time, blinkEvery) < blinkLength)
    }

    /// The next moment after `time` when the frame can change. A view redraws only then.
    public func nextChange(after time: TimeInterval, canBlink: Bool) -> TimeInterval {
        let nextBob = Self.nextMultiple(of: bobStep, after: time)
        guard canBlink else { return nextBob }
        let cycleStart = time - Self.remainder(time, blinkEvery)
        let blinkEnd = cycleStart + blinkLength
        let nextBlinkEdge = blinkEnd > time ? blinkEnd : Self.nextMultiple(of: blinkEvery, after: time)
        return min(nextBob, nextBlinkEdge)
    }

    private static func remainder(_ time: TimeInterval, _ period: TimeInterval) -> TimeInterval {
        let value = time.truncatingRemainder(dividingBy: period)
        return value < 0 ? value + period : value
    }

    private static func nextMultiple(of period: TimeInterval, after time: TimeInterval) -> TimeInterval {
        let next = ((time / period).rounded(.down) + 1) * period
        return next > time ? next : next + period
    }
}
