import BuddyCore
import CoreGraphics
import Foundation
import Testing

@testable import PostureEngine

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

@Suite("PostureEvaluator.check (one vote per sensor)")
struct PostureCheckTests {
    let baseline = PostureBaseline(headHeight: 1.0, shoulderWidth: 0.4, shoulderTilt: 0, headPitch: 0)
    let evaluator = PostureEvaluator()

    @Test("Many AirPods readings cannot outvote the camera")
    func cameraOutvotesAirPods() {
        let readings = Array(repeating: cameraReading(), count: 3) + Array(repeating: pitchReading(-30), count: 75)
        let check = evaluator.check(readings, against: baseline)
        #expect(check.cameraVote == .good)
        #expect(check.headphonesVote == .slouching([.headTiltedDown]))
        #expect(check.result == .good)
        #expect(check.decidingSensor == .camera)
    }

    @Test("AirPods decide when the camera saw nobody")
    func airPodsWhenCameraIsBlind() {
        let check = evaluator.check([pitchReading(-30), pitchReading(-25)], against: baseline)
        #expect(check.cameraVote == .unknown)
        #expect(check.result == .slouching([.headTiltedDown]))
        #expect(check.decidingSensor == .headphones)
    }

    @Test("No sensor decides when nobody was seen")
    func noDecidingSensor() {
        #expect(evaluator.check([], against: baseline).decidingSensor == nil)
    }

    @Test("A bad check teaches the baseline nothing")
    func noLearningFromABadCheck() {
        let readings = [cameraReading(), cameraReading(headHeight: 0.5), cameraReading(headHeight: 0.6)]
        let check = evaluator.check(readings, against: baseline)
        #expect(check.result == .slouching([.headDropped]))
        #expect(check.readingsToLearnFrom.isEmpty)
    }

    @Test("A good check teaches only with the good readings of the sensor that decided")
    func learnsFromTheDecidingSensor() {
        let good = [cameraReading(headHeight: 0.95), cameraReading(headHeight: 1.05)]
        let readings = good + [cameraReading(headHeight: 0.5), pitchReading(0)]
        let check = evaluator.check(readings, against: baseline)
        #expect(check.result == .good)
        #expect(check.readingsToLearnFrom == good)
    }
}

@Suite("PostureEvaluator")
struct PostureEvaluatorTests {
    let baseline = PostureBaseline(headHeight: 1.0, shoulderWidth: 0.4, shoulderTilt: 0, headPitch: 0)
    let evaluator = PostureEvaluator()

    @Test func sameAsBaselineIsGood() {
        #expect(evaluator.assess(cameraReading(), against: baseline) == .good)
    }

    @Test func headDropIsSlouching() {
        #expect(evaluator.assess(cameraReading(headHeight: 0.8), against: baseline) == .slouching([.headDropped]))
    }

    @Test func leaningInIsSlouching() {
        #expect(evaluator.assess(cameraReading(shoulderWidth: 0.5), against: baseline) == .slouching([.leaningIn]))
    }

    @Test func sideTiltIsSlouching() {
        #expect(evaluator.assess(cameraReading(shoulderTilt: 12), against: baseline) == .slouching([.leaningSideways]))
    }

    @Test func headphonePitchDown() {
        let reading = PostureReading(timestamp: now, source: .headphones, headPitch: -20, confidence: 1)
        #expect(evaluator.assess(reading, against: baseline) == .slouching([.headTiltedDown]))
    }

    @Test func lowConfidenceIsUnknown() {
        #expect(evaluator.assess(cameraReading(headHeight: 0.1, confidence: 0.2), against: baseline) == .unknown)
    }

    @Test func missingSensorIsNeverBad() {
        let emptyBaseline = PostureBaseline(headHeight: nil, shoulderWidth: nil, shoulderTilt: nil, headPitch: nil)
        #expect(evaluator.assess(cameraReading(headHeight: 0.1), against: emptyBaseline) == .unknown)
    }
}

@Suite("BodyPoseMetrics")
struct BodyPoseMetricsTests {
    @Test func uprightPose() throws {
        let joints = BodyPoseMetrics.Joints(
            nose: CGPoint(x: 0.5, y: 0.7),
            leftShoulder: CGPoint(x: 0.3, y: 0.4),
            rightShoulder: CGPoint(x: 0.7, y: 0.4)
        )
        let reading = try #require(BodyPoseMetrics.reading(from: joints, confidence: 0.9, at: now))
        #expect(abs((reading.shoulderWidth ?? 0) - 0.4) < 0.0001)
        #expect(abs((reading.headHeight ?? 0) - 0.75) < 0.0001)
        #expect(abs(reading.shoulderTilt ?? 99) < 0.0001)
    }

    @Test func mirroredShouldersGiveSameTilt() throws {
        let normal = BodyPoseMetrics.Joints(
            nose: nil, leftShoulder: CGPoint(x: 0.3, y: 0.4), rightShoulder: CGPoint(x: 0.7, y: 0.5))
        let mirrored = BodyPoseMetrics.Joints(
            nose: nil, leftShoulder: CGPoint(x: 0.7, y: 0.5), rightShoulder: CGPoint(x: 0.3, y: 0.4))
        let a = try #require(BodyPoseMetrics.reading(from: normal, confidence: 1, at: now))
        let b = try #require(BodyPoseMetrics.reading(from: mirrored, confidence: 1, at: now))
        #expect(a.shoulderTilt == b.shoulderTilt)
        #expect(a.headHeight == nil)
    }

    @Test func noShouldersNoReading() {
        let joints = BodyPoseMetrics.Joints(
            nose: CGPoint(x: 0.5, y: 0.5), leftShoulder: nil, rightShoulder: CGPoint(x: 0.7, y: 0.4))
        #expect(BodyPoseMetrics.reading(from: joints, confidence: 1, at: now) == nil)
    }
}

@Suite("Posture sensitivity")
struct PostureSensitivityTests {
    private let baseline = PostureBaseline(headHeight: 1.0, shoulderWidth: 0.4, shoulderTilt: 0, headPitch: nil)

    @Test("A 20% head drop is bad when normal or strict, and fine when relaxed")
    func scalesLimits() {
        let reading = cameraReading(headHeight: 0.8)
        func assess(_ sensitivity: PostureSensitivity) -> PostureAssessment {
            PostureEvaluator(thresholds: .standard(for: sensitivity)).assess(reading, against: baseline)
        }
        #expect(assess(.relaxed) == .good)
        #expect(assess(.normal) == .slouching([.headDropped]))
        #expect(assess(.strict) == .slouching([.headDropped]))
        #expect(PostureEvaluator.Thresholds.standard(for: .normal) == .standard)
    }
}
