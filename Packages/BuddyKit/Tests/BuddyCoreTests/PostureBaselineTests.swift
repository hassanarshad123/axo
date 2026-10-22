import Foundation
import Testing

@testable import BuddyCore

private let now = Date(timeIntervalSince1970: 0)

private func cameraReading(
    headHeight: Double? = 1.0,
    shoulderWidth: Double? = 0.4,
    shoulderTilt: Double? = 0,
    confidence: Double = 0.9
) -> PostureReading {
    PostureReading(
        timestamp: now,
        source: .camera,
        headHeight: headHeight,
        shoulderWidth: shoulderWidth,
        shoulderTilt: shoulderTilt,
        confidence: confidence
    )
}

private func pitchReading(_ pitch: Double) -> PostureReading {
    PostureReading(timestamp: now, source: .headphones, headPitch: pitch, confidence: 1)
}

@Suite("PostureBaseline")
struct PostureBaselineTests {
    let anchor = PostureBaseline(headHeight: 1.0, shoulderWidth: 0.4, shoulderTilt: 0, headPitch: 0)

    @Test func averagesConfidentReadings() throws {
        let baseline = try #require(
            PostureBaseline.calibrated(from: [
                cameraReading(headHeight: 1.0),
                cameraReading(headHeight: 1.2),
                cameraReading(headHeight: 9.9, confidence: 0.1),  // ignored: low confidence
            ]))
        #expect(abs((baseline.headHeight ?? 0) - 1.1) < 0.0001)
        #expect(baseline.headPitch == nil)
    }

    @Test func noUsableReadingsGivesNil() {
        #expect(PostureBaseline.calibrated(from: []) == nil)
        #expect(PostureBaseline.calibrated(from: [cameraReading(confidence: 0.2)]) == nil)
    }

    @Test func adaptsSlowly() {
        let baseline = PostureBaseline(headHeight: 1.0, shoulderWidth: 0.4, shoulderTilt: 0, headPitch: nil)
        let adapted = baseline.adapted(toward: cameraReading(headHeight: 2.0), rate: 0.1)
        #expect(abs((adapted.headHeight ?? 0) - 1.1) < 0.0001)
        #expect(baseline.headHeight == 1.0)  // original unchanged
    }

    @Test("Learning takes one small step per check toward the mean of the good readings")
    func learningStepsTowardTheMean() {
        let learned = anchor.learning(
            from: [cameraReading(headHeight: 1.2), cameraReading(headHeight: 1.4)], anchor: anchor, rate: 0.05)
        #expect(abs((learned.headHeight ?? 0) - 1.015) < 0.0001)  // 1.0 + (1.3 - 1.0) * 0.05
        #expect(anchor.headHeight == 1.0)  // original unchanged
    }

    @Test("More readings in one check do not make a bigger step")
    func readingCountDoesNotMatter() {
        let one = anchor.learning(from: [cameraReading(headHeight: 0.95)], anchor: anchor, rate: 0.05)
        let many = anchor.learning(
            from: Array(repeating: cameraReading(headHeight: 0.95), count: 75), anchor: anchor, rate: 0.05)
        #expect(abs((one.headHeight ?? 0) - (many.headHeight ?? 1)) < 1e-9)
        #expect(abs((one.shoulderWidth ?? 0) - (many.shoulderWidth ?? 1)) < 1e-9)
    }

    @Test("Slow slouching cannot drag the baseline more than 10% away from the calibration")
    func driftIsClamped() {
        let drifted = (0..<500).reduce(anchor) { current, _ in
            // Each reading is just inside the "good" range of the current baseline.
            let slouch = cameraReading(
                headHeight: (current.headHeight ?? 1) * 0.86,
                shoulderWidth: (current.shoulderWidth ?? 0.4) * 1.14
            )
            return current.learning(from: [slouch], anchor: anchor, rate: 0.05)
        }
        #expect((drifted.headHeight ?? 0) >= 0.9 - 1e-9)
        #expect((drifted.shoulderWidth ?? 1) <= 0.44 + 1e-9)
    }

    @Test("AirPods pitch and shoulder tilt drift at most a few degrees")
    func degreesAreClamped() {
        let limit = PostureBaseline.DriftLimits.standard.degrees
        let drifted = (0..<500).reduce(anchor) { current, _ in
            current.learning(from: [pitchReading(-14), cameraReading(shoulderTilt: 7)], anchor: anchor, rate: 0.05)
        }
        #expect((drifted.headPitch ?? -99) >= -limit - 1e-9)
        #expect((drifted.shoulderTilt ?? 99) <= limit + 1e-9)
    }

    @Test func noGoodReadingsChangesNothing() {
        #expect(anchor.learning(from: [], anchor: anchor) == anchor)
    }

    @Test("A value the calibration did not measure is never invented")
    func missingFieldsStayMissing() {
        let airPodsOnly = PostureBaseline(headHeight: nil, shoulderWidth: nil, shoulderTilt: nil, headPitch: 0)
        let learned = airPodsOnly.learning(from: [cameraReading()], anchor: airPodsOnly)
        #expect(learned.headHeight == nil)
        #expect(!learned.hasCameraValues)
        #expect(learned.hasHeadphoneValues)
        #expect(anchor.hasCameraValues)
    }
}
