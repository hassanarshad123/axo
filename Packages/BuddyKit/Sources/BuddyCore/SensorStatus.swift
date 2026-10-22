import Foundation

/// How one sensor (camera or AirPods) did in one posture sample.
/// Each sensor keeps its own message, so AirPods working never hides a camera problem.
public enum SensorStatus: Sendable, Equatable {
    /// The sensor was off, or not allowed to run this time (for example the user was idle).
    case notUsed
    case worked
    /// A message the user can read, for example "No camera found".
    case failed(String)

    /// The message to show after this sample, given the one shown before it.
    public func message(after previous: String?) -> String? {
        switch self {
        case .notUsed: previous
        case .worked: nil
        case .failed(let message): message
        }
    }
}
