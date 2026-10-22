import Foundation

/// One stretch the buddy shows. The raw value is the pose name in the buddy art (`neck-left.png`).
public enum StretchMove: String, CaseIterable, Codable, Sendable {
    case neckLeft = "neck-left"
    case neckRight = "neck-right"
    case chinTuck = "chin-tuck"
    case shrug
    case chestOpen = "chest-open"
    case twistLeft = "twist-left"
    case twistRight = "twist-right"
    case wrist
    case reach
    case sideBend = "side-bend"
    case march
    case walk
    case breathe
    case palming
    case sitTall = "sit-tall"
    case lookFar = "look-far"

    /// The art to show. Looking far away uses the eye-rest pose.
    public var pose: String { self == .lookFar ? "eyes" : rawValue }

    /// The words on screen. The voice line says the same thing in more words.
    public var instruction: String {
        switch self {
        case .neckLeft: "Tilt your head to the left. Ear toward shoulder."
        case .neckRight: "Now tilt your head to the right."
        case .chinTuck: "Pull your chin straight back. Hold it there."
        case .shrug: "Lift your shoulders up to your ears, then let them drop."
        case .chestOpen: "Hands behind you. Open your chest and look ahead."
        case .twistLeft: "Sit tall and turn your upper body to the left."
        case .twistRight: "Now turn to the right."
        case .wrist: "Arm out, palm up. Gently pull your fingers back."
        case .reach: "Reach both arms up high. Grow tall."
        case .sideBend: "Arms up, and lean slowly to one side, then the other."
        case .march: "Stand up and march on the spot."
        case .walk: "Take a short walk. Get some water on the way."
        case .breathe: "Breathe in for four. Breathe out for six."
        case .palming: "Close your eyes. Cup your palms over them."
        case .sitTall: "Sit tall. Shoulders down, head over your shoulders."
        case .lookFar: "Look at something far away, 20 feet or more."
        }
    }

    public var voiceLine: VoiceLine {
        switch self {
        case .neckLeft: .stepNeckLeft
        case .neckRight: .stepNeckRight
        case .chinTuck: .stepChinTuck
        case .shrug: .stepShrug
        case .chestOpen: .stepChestOpen
        case .twistLeft: .stepTwistLeft
        case .twistRight: .stepTwistRight
        case .wrist: .stepWrist
        case .reach: .stepReach
        case .sideBend: .stepSideBend
        case .march: .stepMarch
        case .walk: .stepWalk
        case .breathe: .stepBreathe
        case .palming: .stepPalming
        case .sitTall: .stepSitTall
        case .lookFar: .stepLookFar
        }
    }
}

/// A set of stretches for one break. Each reminder kind has a default; the user can pick another.
///
///     neck and shoulders (90 s):  neck-left 15 │ neck-right 15 │ chin-tuck 15 │ shrug 15 │ chest-open 15 │ reach 15
public struct StretchRoutine: Identifiable, Hashable, Sendable {
    public struct Step: Hashable, Sendable {
        public let move: StretchMove
        public let seconds: TimeInterval

        public init(_ move: StretchMove, _ seconds: TimeInterval) {
            self.move = move
            self.seconds = seconds
        }
    }

    public let id: String
    public let title: String
    public let steps: [Step]

    /// A cut last step shorter than this joins the step before it.
    static let shortestStep: TimeInterval = 5

    public var duration: TimeInterval { steps.reduce(0) { $0 + $1.seconds } }

    /// The steps for a break of `duration` seconds. The routine repeats until the time is full,
    /// and the last step is cut to fit. A routine with no steps gives no steps.
    public func steps(fitting duration: TimeInterval) -> [Step] {
        guard !steps.isEmpty, duration > 0 else { return [] }
        var fitted: [Step] = []
        var left = duration
        var index = 0
        while left > 0 {
            let step = steps[index % steps.count]
            let seconds = min(step.seconds, left)
            if seconds < Self.shortestStep, let last = fitted.popLast() {
                fitted.append(Step(last.move, last.seconds + seconds))
            } else {
                fitted.append(Step(step.move, seconds))
            }
            left -= seconds
            index += 1
        }
        return fitted
    }
}

public extension StretchRoutine {
    static let neckAndShoulders = StretchRoutine(
        id: "neck-shoulders", title: "Neck and shoulders",
        steps: [
            Step(.neckLeft, 15), Step(.neckRight, 15), Step(.chinTuck, 15),
            Step(.shrug, 15), Step(.chestOpen, 15), Step(.reach, 15),
        ])
    static let neck = StretchRoutine(
        id: "neck", title: "Neck",
        steps: [Step(.neckLeft, 15), Step(.neckRight, 15), Step(.chinTuck, 15), Step(.sitTall, 15)])
    static let back = StretchRoutine(
        id: "back", title: "Back",
        steps: [
            Step(.twistLeft, 15), Step(.twistRight, 15), Step(.sideBend, 20), Step(.reach, 15), Step(.sitTall, 15),
        ])
    static let wrists = StretchRoutine(
        id: "wrists", title: "Wrists and arms", steps: [Step(.wrist, 20), Step(.reach, 15), Step(.shrug, 15)])
    static let eyes = StretchRoutine(id: "eyes", title: "Eyes", steps: [Step(.lookFar, 20), Step(.palming, 20)])
    static let standAndMove = StretchRoutine(
        id: "stand-move", title: "Stand and move",
        steps: [Step(.march, 30), Step(.walk, 60), Step(.reach, 15), Step(.breathe, 15)])
    static let breathing = StretchRoutine(id: "breathe", title: "Slow breathing", steps: [Step(.breathe, 60)])
    /// No moves: the break shows a countdown and the reminder's own message.
    static let timer = StretchRoutine(id: "timer", title: "Just a timer", steps: [])

    /// In the order the routine picker shows them.
    static let all: [StretchRoutine] = [neckAndShoulders, neck, back, wrists, eyes, standAndMove, breathing, timer]

    static func routine(id: String?) -> StretchRoutine? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }

    static func defaultRoutine(for kind: Reminder.Kind) -> StretchRoutine {
        switch kind {
        case .standUp: standAndMove
        case .stretch: neckAndShoulders
        case .eyeRest: eyes
        case .drinkWater, .custom: timer
        }
    }
}

public extension Reminder {
    /// The routine for this reminder's break: its own pick, or the default for its kind.
    var routine: StretchRoutine {
        StretchRoutine.routine(id: routineID) ?? StretchRoutine.defaultRoutine(for: kind)
    }
}
