import Foundation
import Testing

@testable import BuddyCore

@Suite("Voice script")
struct VoiceScriptTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)

    private func line(_ event: EngineEvent, hour: Int = 10, turn: Int = 0) -> VoiceLine? {
        VoiceScript.line(for: event, hour: hour, turn: turn)
    }

    private func reminder(_ kind: Reminder.Kind, breakSeconds: TimeInterval = 0, routine: String? = nil) -> Reminder {
        Reminder(
            kind: kind, title: "t", message: "m", interval: 600, breakDuration: breakSeconds, routineID: routine)
    }

    private func session(_ reminder: Reminder) throws -> BreakSession {
        try #require(BreakSession(reminder: reminder, style: .gentle, startedAt: start))
    }

    @Test("Hello fits the time of day")
    func helloByHour() {
        #expect(line(.appStarted, hour: 4) == .helloMorning)
        #expect(line(.appStarted, hour: 11) == .helloMorning)
        #expect(line(.appStarted, hour: 12) == .helloAfternoon)
        #expect(line(.appStarted, hour: 16) == .helloAfternoon)
        #expect(line(.appStarted, hour: 17) == .helloEvening)
        #expect(line(.appStarted, hour: 2) == .helloEvening)
    }

    @Test("Welcome back only after 15 minutes away")
    func welcomeBack() {
        #expect(line(.cameBack(awayFor: 14 * 60)) == nil)
        #expect(line(.cameBack(awayFor: 15 * 60)) == .welcomeBack)
    }

    @Test("Each reminder kind has its own words, and the words change from turn to turn")
    func reminderRotation() {
        let stand = (0..<4).map { line(.reminderDue(reminder(.standUp)), turn: $0) }
        #expect(stand == [.remindStand1, .remindStand2, .remindStand3, .remindStand1])
        #expect(line(.reminderDue(reminder(.eyeRest)), turn: 1) == .remindEyes2)
        #expect(line(.reminderDue(reminder(.stretch)), turn: 2) == .remindStretch1)
        #expect(line(.reminderDue(reminder(.drinkWater)), turn: 1) == .remindWater2)
        #expect(line(.reminderDue(reminder(.custom)), turn: 5) == .remindCustom)
    }

    @Test("Done, snooze, a break start and plain checks say nothing")
    func quietEvents() throws {
        #expect(line(.reminderDone(reminder(.standUp))) == nil)
        #expect(line(.reminderSnoozed(reminder(.standUp))) == nil)
        #expect(line(.breakStarted(try session(reminder(.stretch, breakSeconds: 90)))) == nil)
        #expect(line(.postureChecked(.good, sensor: .camera)) == nil)
        #expect(line(.atMac(seconds: 5)) == nil)
    }

    @Test("A nudge names the first problem")
    func nudgeByIssue() {
        #expect(line(.postureNudged(.slouching([.headTiltedDown, .leaningIn]))) == .postureLiftHead)
        #expect(line(.postureNudged(.slouching([.leaningIn]))) == .postureLeanBack)
        #expect(line(.postureNudged(.slouching([.leaningSideways]))) == .postureLevelShoulders)
        #expect(line(.postureNudged(.slouching([.headDropped])), turn: 0) == .postureSitTall)
        #expect(line(.postureNudged(.slouching([.headDropped])), turn: 1) == .postureShouldersDown)
        #expect(line(.postureNudged(.slouching([]))) == .postureSitTall)
        #expect(line(.postureFixed) == .postureFixed)
    }

    @Test("A break end gets praise, a kind word, or nothing")
    func breakEnd() throws {
        let stretch = try session(reminder(.stretch, breakSeconds: 90))
        #expect(line(.breakEnded(stretch, .finished), turn: 0) == .breakDone1)
        #expect(line(.breakEnded(stretch, .finished), turn: 1) == .breakDone2)
        #expect(line(.breakEnded(stretch, .skipped)) == .breakSkipped)
        #expect(line(.breakEnded(stretch, .emergencyExit)) == .breakSkipped)
        #expect(line(.breakEnded(stretch, .interrupted)) == nil)
    }

    @Test("Progress and calibration have their own lines")
    func progressAndCalibration() {
        #expect(line(.milestone(.dailyGoal)) == .dailyGoal)
        #expect(line(.milestone(.streak(3))) == .streak)
        #expect(line(.milestone(.weeklyGoal)) == .weeklyGoal)
        #expect(line(.milestone(.levelUp(4))) == .levelUp)
        #expect(line(.milestone(.grewUp(3))) == .grewUp)
        #expect(line(.calibrationStarted) == .calibrateStart)
        #expect(line(.calibrationEnded(succeeded: true)) == .calibrateDone)
        #expect(line(.calibrationEnded(succeeded: false)) == .calibrateFailed)
    }

    @Test("A long stretch break: start, each move, then 3-2-1 before the end")
    func longBreakPlan() throws {
        let plan = VoiceScript.breakPlan(for: try session(reminder(.stretch, breakSeconds: 90)))
        #expect(plan.first == VoiceScript.Cue(offset: 0, line: .breakStart))
        #expect(plan.dropFirst().prefix(3).map(\.line) == [.stepNeckLeft, .stepNeckRight, .stepChinTuck])
        #expect(plan.dropFirst().prefix(3).map(\.offset) == [0, 15, 30])
        #expect(plan.last == VoiceScript.Cue(offset: 87, line: .countThreeTwoOne))
        #expect(plan.count == 1 + 6 + 1)
    }

    @Test("A short break with moves skips the start line")
    func shortBreakPlan() throws {
        let plan = VoiceScript.breakPlan(for: try session(reminder(.eyeRest, breakSeconds: 20)))
        #expect(plan == [.init(offset: 0, line: .stepLookFar), .init(offset: 17, line: .countThreeTwoOne)])
    }

    @Test("A timer break: start, halfway when it is long, then 3-2-1")
    func timerBreakPlan() throws {
        let long = VoiceScript.breakPlan(for: try session(reminder(.custom, breakSeconds: 120, routine: "timer")))
        #expect(
            long == [
                .init(offset: 0, line: .breakStart), .init(offset: 60, line: .breakHalfway),
                .init(offset: 117, line: .countThreeTwoOne),
            ])
        let short = VoiceScript.breakPlan(for: try session(reminder(.custom, breakSeconds: 30, routine: "timer")))
        #expect(short == [.init(offset: 0, line: .breakStart), .init(offset: 27, line: .countThreeTwoOne)])
    }

    @Test("No 3-2-1 when a move starts close to the end")
    func noCountOverAMove() throws {
        // 35 s of neck: 15 + 15 + 5. The last move starts 5 s before the end.
        let plan = VoiceScript.breakPlan(for: try session(reminder(.stretch, breakSeconds: 35, routine: "neck")))
        #expect(plan.map(\.line) == [.stepNeckLeft, .stepNeckRight, .stepChinTuck])
    }

    @Test("A very short break gets no 3-2-1")
    func tinyBreak() throws {
        let plan = VoiceScript.breakPlan(for: try session(reminder(.custom, breakSeconds: 6, routine: "timer")))
        #expect(plan == [.init(offset: 0, line: .breakStart)])
    }
}

@Suite("Voice files")
struct VoiceFilesTests {
    /// The repo root, from this file's place: Packages/BuddyKit/Tests/BuddyCoreTests/.
    private let root = URL(filePath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()

    @Test("Each line has a recording and a row of words, and no recording is left over")
    func everyLineHasAFile() throws {
        let folder = root.appending(path: "App/Resources/Voice")
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))
            .filter { $0.hasSuffix(".m4a") }
        let ids = Set(VoiceLine.allCases.map(\.rawValue))
        #expect(Set(files.map { String($0.dropLast(4)) }) == ids)

        let table = try String(contentsOf: root.appending(path: "design/voice/lines.tsv"), encoding: .utf8)
        let rows = table.split(separator: "\n").dropFirst().compactMap { $0.split(separator: "\t").first }
        #expect(Set(rows.map(String.init)) == ids)
    }
}

@Suite("Voice queue")
struct VoiceQueueTests {
    private let now = Date(timeIntervalSinceReferenceDate: 5_000)

    @Test("Lines come out first in, first out")
    func order() {
        let queue = VoiceQueue.empty.adding(.breakStart, at: now).adding(.stepWalk, at: now)
        let (first, rest) = queue.next(at: now)
        #expect(first == .breakStart)
        #expect(rest.next(at: now).line == .stepWalk)
        #expect(rest.next(at: now).rest.isEmpty)
    }

    @Test("A full queue drops its oldest line")
    func cap() {
        let lines: [VoiceLine] = [.helloMorning, .remindStand1, .postureSitTall, .dailyGoal]
        let queue = lines.reduce(VoiceQueue.empty) { $0.adding($1, at: now) }
        #expect(queue.count == VoiceQueue.capacity)
        #expect(queue.next(at: now).line == .remindStand1)
    }

    @Test("A line that waited too long is dropped, not said late")
    func stale() {
        let queue = VoiceQueue.empty.adding(.remindStand1, at: now).adding(.postureFixed, at: now.addingTimeInterval(8))
        let (line, rest) = queue.next(at: now.addingTimeInterval(VoiceQueue.staleAfter + 1))
        #expect(line == .postureFixed)
        #expect(rest.isEmpty)
        #expect(VoiceQueue.empty.next(at: now).line == nil)
    }

    @Test("The coach speaks only when the user can hear it and is not busy")
    func gate() {
        func canSpeak(
            voice: Bool = true, activity: ActivityState = .active, locked: Bool = false, mic: Bool = false
        ) -> Bool {
            VoiceGate.canSpeak(
                voiceEnabled: voice, activity: activity, isScreenLockedOrAsleep: locked, microphoneInUse: mic)
        }
        #expect(canSpeak())
        #expect(canSpeak(activity: .away))  // a walk break has no typing
        #expect(!canSpeak(voice: false))
        #expect(!canSpeak(activity: .inMeeting))
        #expect(!canSpeak(activity: .paused))
        #expect(!canSpeak(locked: true))
        #expect(!canSpeak(mic: true))
    }
}
