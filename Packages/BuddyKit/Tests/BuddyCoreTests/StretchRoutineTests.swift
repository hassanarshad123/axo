import Testing

@testable import BuddyCore

@Suite("StretchRoutine")
struct StretchRoutineTests {
    @Test("Each built-in reminder has a routine whose whole steps fill its default break")
    func defaultsFitTheirBreak() {
        for reminder in Reminder.defaults where reminder.breakDuration > 0 {
            let routine = StretchRoutine.defaultRoutine(for: reminder.kind)
            let steps = routine.steps(fitting: reminder.breakDuration)
            #expect(steps.reduce(0) { $0 + $1.seconds } == reminder.breakDuration, "\(reminder.kind)")
            #expect(steps == Array(routine.steps.prefix(steps.count)), "no step is cut: \(reminder.kind)")
        }
        #expect(StretchRoutine.defaultRoutine(for: .standUp) == .standAndMove)
        #expect(StretchRoutine.defaultRoutine(for: .stretch) == .neckAndShoulders)
        #expect(StretchRoutine.defaultRoutine(for: .eyeRest) == .eyes)
        #expect(StretchRoutine.defaultRoutine(for: .drinkWater) == .timer)
        #expect(StretchRoutine.defaultRoutine(for: .custom) == .timer)
    }

    @Test("Routine ids are unique and can be found again")
    func idsAreUnique() {
        let ids = StretchRoutine.all.map(\.id)
        #expect(Set(ids).count == ids.count)
        for routine in StretchRoutine.all {
            #expect(StretchRoutine.routine(id: routine.id) == routine)
        }
        #expect(StretchRoutine.routine(id: "gone") == nil)
        #expect(StretchRoutine.routine(id: nil) == nil)
    }

    @Test("A reminder uses its own routine, or the default one for its kind")
    func reminderRoutine() {
        let stand = Reminder.defaults[0]
        #expect(stand.routine == .standAndMove)
        #expect(stand.withRoutine("back").routine == .back)
        #expect(stand.withRoutine("gone").routine == .standAndMove)
        #expect(stand.withRoutine("back").withRoutine(nil).routine == .standAndMove)
    }

    @Test("A routine repeats until the break is full, and the last step is cut")
    func fitsALongerBreak() {
        // Eyes: look far 20 s, palming 20 s.
        let steps = StretchRoutine.eyes.steps(fitting: 50)
        #expect(steps.map(\.move) == [.lookFar, .palming, .lookFar])
        #expect(steps.map(\.seconds) == [20, 20, 10])
    }

    @Test("A short break takes only the first steps")
    func fitsAShorterBreak() {
        let steps = StretchRoutine.neckAndShoulders.steps(fitting: 40)
        #expect(steps.map(\.move) == [.neckLeft, .neckRight, .chinTuck])
        #expect(steps.map(\.seconds) == [15, 15, 10])
    }

    @Test("A cut step shorter than 5 s is added to the step before it")
    func tinyRemainderJoinsThePreviousStep() {
        let steps = StretchRoutine.neckAndShoulders.steps(fitting: 33)
        #expect(steps.map(\.move) == [.neckLeft, .neckRight])
        #expect(steps.map(\.seconds) == [15, 18])
        // With nothing before it, a short break is one short step.
        #expect(StretchRoutine.neck.steps(fitting: 3).map(\.seconds) == [3])
    }

    @Test("The timer routine and a zero break have no steps")
    func noSteps() {
        #expect(StretchRoutine.timer.steps(fitting: 120).isEmpty)
        #expect(StretchRoutine.neck.steps(fitting: 0).isEmpty)
    }

    @Test("Every move has a pose, an instruction and its voice line")
    func movesAreComplete() {
        for move in StretchMove.allCases {
            #expect(!move.pose.isEmpty)
            #expect(!move.instruction.isEmpty)
            #expect(move.instruction.count <= 80, "\(move)")
            #expect(move.voiceLine.rawValue == "step-\(move.rawValue)")
        }
        #expect(StretchMove.lookFar.pose == "eyes")
        #expect(StretchMove.neckLeft.pose == "neck-left")
    }
}
