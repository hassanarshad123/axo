import Foundation

/// The pages of the first-start window, in order.
public enum OnboardingStep: Int, CaseIterable, Sendable {
    case welcome
    case buddy
    case privacy
    case permissions
    case airPods
    case calibrate
    case done

    public var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    public var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }

    public var title: String {
        switch self {
        case .welcome: "Meet your buddy"
        case .buddy: "Pick your buddy"
        case .privacy: "Your camera stays yours"
        case .permissions: "Camera and alerts"
        case .airPods: "AirPods, if you have them"
        case .calibrate: "Sit tall"
        case .done: "All set"
        }
    }
}

/// How much room the posture checks give before a check counts as bad. The user picks it.
public enum PostureSensitivity: String, Codable, Sendable, CaseIterable, Identifiable {
    case relaxed
    case normal
    case strict

    public var id: String { rawValue }

    /// Multiplies every posture limit. More than 1 = more room.
    public var limitScale: Double {
        switch self {
        case .relaxed: 1.4
        case .normal: 1
        case .strict: 0.7
        }
    }

    public var title: String {
        switch self {
        case .relaxed: "Relaxed"
        case .normal: "Normal"
        case .strict: "Strict"
        }
    }
}
