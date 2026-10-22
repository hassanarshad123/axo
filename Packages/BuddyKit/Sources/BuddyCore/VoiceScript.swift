import Foundation

/// What the voice coach says, and when. Pure rules: the app plays the files (`VoiceCoach`).
///
///     EngineEvent ──▶ line(for:) ──▶ VoiceQueue ──▶ VoiceGate ──▶ play
///     breakStarted ──▶ breakPlan(for:) ──▶ one line at each offset
///
/// `turn` picks between lines with the same meaning, so the coach does not repeat itself.
public enum VoiceScript {
    /// Away for less than this is a short pause: no "welcome back". A coffee or a meal is longer.
    public static let welcomeBackAfter: TimeInterval = 15 * 60
    /// A break this long (or a break with no moves) opens with "your break starts now".
    public static let startLineFrom: TimeInterval = 60
    /// A break with no moves this long gets "you are halfway there".
    public static let halfwayLineFrom: TimeInterval = 60
    /// "Three, two, one" starts this many seconds before the end of a break.
    public static let countdownLead: TimeInterval = 3
    /// "Three, two, one" only when the last line started at least this long before the end.
    /// Closer than that, the last line may still be playing.
    public static let countdownClearance: TimeInterval = 8

    /// One line at a time offset from the start of a break.
    public struct Cue: Sendable, Equatable {
        public let offset: TimeInterval
        public let line: VoiceLine

        public init(offset: TimeInterval, line: VoiceLine) {
            self.offset = offset
            self.line = line
        }
    }

    /// The line for this event. Nil when the coach stays quiet.
    public static func line(for event: EngineEvent, hour: Int, turn: Int) -> VoiceLine? {
        switch event {
        case .appStarted: hello(hour: hour)
        case .cameBack(let away): away >= welcomeBackAfter ? .welcomeBack : nil
        case .reminderDue(let reminder): pick(reminderLines(reminder.kind), turn)
        case .postureNudged(let assessment): nudge(assessment, turn: turn)
        case .postureFixed: .postureFixed
        case .breakEnded(_, let outcome): breakEnd(outcome, turn: turn)
        case .milestone(let milestone): progress(milestone)
        case .calibrationStarted: .calibrateStart
        case .calibrationEnded(let succeeded): succeeded ? .calibrateDone : .calibrateFailed
        case .reminderDone, .reminderSnoozed, .breakStarted, .postureChecked, .atMac, .setupFinished, .buddyPicked:
            nil
        }
    }

    /// The lines of one break, in time order. The moves come from the break's routine.
    public static func breakPlan(for session: BreakSession) -> [Cue] {
        var cues: [Cue] = []
        if session.steps.isEmpty || session.duration >= startLineFrom {
            cues.append(Cue(offset: 0, line: .breakStart))
        }
        var stepStart: TimeInterval = 0
        for step in session.steps {
            cues.append(Cue(offset: stepStart, line: step.move.voiceLine))
            stepStart += step.seconds
        }
        if session.steps.isEmpty, session.duration >= halfwayLineFrom {
            cues.append(Cue(offset: session.duration / 2, line: .breakHalfway))
        }
        let lastLineStart = cues.map(\.offset).max() ?? 0
        if session.duration - lastLineStart >= countdownClearance {
            cues.append(Cue(offset: session.duration - countdownLead, line: .countThreeTwoOne))
        }
        return cues
    }

    // MARK: - Lines for each event

    private static func hello(hour: Int) -> VoiceLine {
        switch hour {
        case 4..<12: .helloMorning
        case 12..<17: .helloAfternoon
        default: .helloEvening
        }
    }

    private static func reminderLines(_ kind: Reminder.Kind) -> [VoiceLine] {
        switch kind {
        case .standUp: [.remindStand1, .remindStand2, .remindStand3]
        case .eyeRest: [.remindEyes1, .remindEyes2]
        case .stretch: [.remindStretch1, .remindStretch2]
        case .drinkWater: [.remindWater1, .remindWater2]
        case .custom: [.remindCustom]
        }
    }

    /// The first problem decides. A dropped head is the plain slouch, so it has two lines.
    private static func nudge(_ assessment: PostureAssessment, turn: Int) -> VoiceLine {
        guard case .slouching(let issues) = assessment, let first = issues.first else { return .postureSitTall }
        switch first {
        case .headDropped: return pick([.postureSitTall, .postureShouldersDown], turn)
        case .headTiltedDown: return .postureLiftHead
        case .leaningIn: return .postureLeanBack
        case .leaningSideways: return .postureLevelShoulders
        }
    }

    /// A break cut short by a call or a locked screen gets no line: the user is busy or gone.
    private static func breakEnd(_ outcome: BreakOutcome, turn: Int) -> VoiceLine? {
        switch outcome {
        case .finished: pick([.breakDone1, .breakDone2], turn)
        case .skipped, .emergencyExit: .breakSkipped
        case .interrupted: nil
        }
    }

    private static func progress(_ milestone: ProgressMilestone) -> VoiceLine {
        switch milestone {
        case .dailyGoal: .dailyGoal
        case .streak: .streak
        case .weeklyGoal: .weeklyGoal
        case .levelUp: .levelUp
        case .grewUp: .grewUp
        }
    }

    private static func pick(_ lines: [VoiceLine], _ turn: Int) -> VoiceLine {
        lines[abs(turn) % lines.count]
    }
}

/// When the coach may speak. Never in a call, while paused, on a locked screen,
/// or while any app uses the microphone (the coach only asks if the mic runs, it never listens).
/// Away is fine: during a walk break nobody types.
public enum VoiceGate {
    public static func canSpeak(
        voiceEnabled: Bool, activity: ActivityState, isScreenLockedOrAsleep: Bool, microphoneInUse: Bool
    ) -> Bool {
        guard voiceEnabled, !isScreenLockedOrAsleep, !microphoneInUse else { return false }
        return activity != .inMeeting && activity != .paused
    }
}
