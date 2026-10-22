import Foundation

/// One posture measurement. Fields are optional because each sensor sees different things:
/// the camera sees head and shoulders, AirPods see only head angle.
public struct PostureReading: Codable, Sendable, Equatable {
    public enum Source: String, Codable, Sendable {
        case camera
        case headphones
    }

    public let timestamp: Date
    public let source: Source
    /// Nose height above the shoulder line, divided by shoulder width. Drops when the user slouches.
    public let headHeight: Double?
    /// Shoulder width as a fraction of the camera frame width. Grows when the user leans toward the screen.
    public let shoulderWidth: Double?
    /// Shoulder line angle in degrees. Not zero when the user leans to one side.
    public let shoulderTilt: Double?
    /// Head pitch in degrees from AirPods. Negative when the head drops forward.
    public let headPitch: Double?
    /// 0...1. How sure the sensor is.
    public let confidence: Double

    public init(
        timestamp: Date,
        source: Source,
        headHeight: Double? = nil,
        shoulderWidth: Double? = nil,
        shoulderTilt: Double? = nil,
        headPitch: Double? = nil,
        confidence: Double
    ) {
        self.timestamp = timestamp
        self.source = source
        self.headHeight = headHeight
        self.shoulderWidth = shoulderWidth
        self.shoulderTilt = shoulderTilt
        self.headPitch = headPitch
        self.confidence = min(max(confidence, 0), 1)
    }
}

/// The result of comparing a reading with the user's good posture.
public enum PostureAssessment: Sendable, Equatable {
    case good
    case slouching([PostureIssue])
    /// No usable reading (user not in frame, low confidence, sensor off).
    case unknown

    public var isGood: Bool { self == .good }

    /// Joins the checks from one sample window (several frames, maybe two sensors) into one answer.
    /// Slouching wins if at least half of the known checks are slouching.
    public static func majority(_ assessments: [PostureAssessment]) -> PostureAssessment {
        let known = assessments.filter { $0 != .unknown }
        guard !known.isEmpty else { return .unknown }

        let slouchIssues = known.compactMap { assessment -> [PostureIssue]? in
            if case let .slouching(issues) = assessment { return issues }
            return nil
        }
        guard slouchIssues.count * 2 >= known.count else { return .good }

        let allIssues = Set(slouchIssues.flatMap { $0 })
        return .slouching(PostureIssue.allCases.filter(allIssues.contains))
    }

    /// One vote per sensor. The camera decides when it saw the user; AirPods are the backup
    /// (docs/DECISIONS.md #2). AirPods send many more readings, so they must not join the camera's vote.
    public static func combined(camera: PostureAssessment, headphones: PostureAssessment) -> PostureAssessment {
        camera == .unknown ? headphones : camera
    }
}

public enum PostureIssue: String, Codable, Sendable, Equatable, CaseIterable {
    case headDropped
    case leaningIn
    case leaningSideways
    case headTiltedDown
}
