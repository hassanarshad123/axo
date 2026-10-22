import BuddyCore
import Foundation

/// The result of one posture check (one 3-second sample from the camera and maybe AirPods).
///
///     camera readings ──majority──▶ cameraVote ─┐
///                                               ├─ camera first, AirPods only if the camera is unknown ─▶ result
///     AirPods readings ─majority──▶ headphonesVote ┘
public struct PostureCheck: Sendable, Equatable {
    public let cameraVote: PostureAssessment
    public let headphonesVote: PostureAssessment
    /// The good readings of the sensor that decided the result.
    public let goodReadings: [PostureReading]

    public init(cameraVote: PostureAssessment, headphonesVote: PostureAssessment, goodReadings: [PostureReading]) {
        self.cameraVote = cameraVote
        self.headphonesVote = headphonesVote
        self.goodReadings = goodReadings
    }

    public var result: PostureAssessment {
        .combined(camera: cameraVote, headphones: headphonesVote)
    }

    /// The sensor whose vote is the result. Nil when neither sensor saw the user.
    public var decidingSensor: PostureReading.Source? {
        if cameraVote != .unknown { return .camera }
        return headphonesVote != .unknown ? .headphones : nil
    }

    /// What the baseline may learn from: nothing unless the whole check was good.
    public var readingsToLearnFrom: [PostureReading] {
        result == .good ? goodReadings : []
    }
}

extension PostureEvaluator {
    /// Judges every reading, then votes once per sensor.
    public func check(_ readings: [PostureReading], against baseline: PostureBaseline) -> PostureCheck {
        let judged = readings.map { (reading: $0, assessment: assess($0, against: baseline)) }

        func vote(_ source: PostureReading.Source) -> PostureAssessment {
            .majority(judged.filter { $0.reading.source == source }.map(\.assessment))
        }
        let cameraVote = vote(.camera)
        let decidingSource: PostureReading.Source = cameraVote == .unknown ? .headphones : .camera
        let goodReadings =
            judged
            .filter { $0.reading.source == decidingSource && $0.assessment == .good }
            .map(\.reading)

        return PostureCheck(cameraVote: cameraVote, headphonesVote: vote(.headphones), goodReadings: goodReadings)
    }
}
