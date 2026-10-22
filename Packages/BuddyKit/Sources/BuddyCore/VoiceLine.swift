import Foundation

/// One recorded line of the voice coach. The raw value is the file name in `App/Resources/Voice`
/// (`<id>.m4a`) and the id in `design/voice/lines.tsv`, where the words live.
public enum VoiceLine: String, CaseIterable, Sendable {
    // Posture nudges, and praise after the user sat up.
    case postureSitTall = "posture-sit-tall"
    case postureLiftHead = "posture-lift-head"
    case postureShouldersDown = "posture-shoulders-down"
    case postureLeanBack = "posture-lean-back"
    case postureLevelShoulders = "posture-level-shoulders"
    case postureFixed = "posture-fixed"

    // Reminders, a few words for each kind so the coach does not repeat itself.
    case remindStand1 = "remind-stand-1"
    case remindStand2 = "remind-stand-2"
    case remindStand3 = "remind-stand-3"
    case remindEyes1 = "remind-eyes-1"
    case remindEyes2 = "remind-eyes-2"
    case remindStretch1 = "remind-stretch-1"
    case remindStretch2 = "remind-stretch-2"
    case remindWater1 = "remind-water-1"
    case remindWater2 = "remind-water-2"
    case remindCustom = "remind-custom"

    // Breaks.
    case breakStart = "break-start"
    case breakHalfway = "break-halfway"
    case breakDone1 = "break-done-1"
    case breakDone2 = "break-done-2"
    case breakSkipped = "break-skipped"

    // One line for each stretch move (`StretchMove.voiceLine`).
    case stepNeckLeft = "step-neck-left"
    case stepNeckRight = "step-neck-right"
    case stepChinTuck = "step-chin-tuck"
    case stepShrug = "step-shrug"
    case stepChestOpen = "step-chest-open"
    case stepTwistLeft = "step-twist-left"
    case stepTwistRight = "step-twist-right"
    case stepWrist = "step-wrist"
    case stepReach = "step-reach"
    case stepSideBend = "step-side-bend"
    case stepMarch = "step-march"
    case stepWalk = "step-walk"
    case stepBreathe = "step-breathe"
    case stepPalming = "step-palming"
    case stepSitTall = "step-sit-tall"
    case stepLookFar = "step-look-far"

    // Counting.
    case countThreeTwoOne = "count-3-2-1"
    case countHold = "count-hold"
    case countOtherSide = "count-other-side"
    case countRelax = "count-relax"

    // Hello and welcome back.
    case helloMorning = "hello-morning"
    case helloAfternoon = "hello-afternoon"
    case helloEvening = "hello-evening"
    case welcomeBack = "welcome-back"

    // Calibration.
    case calibrateStart = "calibrate-start"
    case calibrateDone = "calibrate-done"
    case calibrateFailed = "calibrate-failed"

    // Progress.
    case levelUp = "level-up"
    case grewUp = "grew-up"
    case streak = "streak"
    case dailyGoal = "daily-goal"
    case weeklyGoal = "weekly-goal"
}
