import Foundation
import Testing

@testable import BuddyCore

@Suite("Usage counts")
struct UsageSignalTests {
    private let water = Reminder.defaults[3]
    private let stretch = Reminder.defaults[2]

    private func session() throws -> BreakSession {
        try #require(BreakSession(reminder: stretch, style: .gentle, startedAt: Date()))
    }

    @Test("Only the listed events become counts, with the reminder kind and nothing else")
    func mapping() throws {
        #expect(UsageSignal(.appStarted) == UsageSignal(name: "App.started"))
        #expect(
            UsageSignal(.reminderDone(water)) == UsageSignal(name: "Reminder.done", parameters: ["kind": "drinkWater"]))
        #expect(
            UsageSignal(.reminderSnoozed(stretch))
                == UsageSignal(name: "Reminder.snoozed", parameters: ["kind": "stretch"]))
        #expect(
            UsageSignal(.breakEnded(try session(), .finished))
                == UsageSignal(name: "Break.finished", parameters: ["kind": "stretch"]))
        #expect(
            UsageSignal(.setupFinished(buddyID: "10-neko-cat"))
                == UsageSignal(name: "Setup.finished", parameters: ["buddy": "10-neko-cat"]))
        #expect(
            UsageSignal(.buddyPicked(buddyID: "29-hassan-desi"))
                == UsageSignal(name: "Buddy.picked", parameters: ["buddy": "29-hassan-desi"]))
    }

    @Test("Posture, presence, voice and progress events are never counted")
    func neverCounted() throws {
        let quiet: [EngineEvent] = [
            .postureChecked(.good, sensor: .camera), .postureNudged(.slouching([.leaningIn])), .postureFixed,
            .cameBack(awayFor: 600), .atMac(seconds: 5), .milestone(.levelUp(3)), .reminderDue(water),
            .breakStarted(try session()), .breakEnded(try session(), .skipped), .calibrationStarted,
            .calibrationEnded(succeeded: true),
        ]
        #expect(quiet.compactMap(UsageSignal.init).isEmpty)
    }

    @Test("A buddy that is not open (a locked pack or an unknown id) goes as \"locked\"")
    func lockedBuddy() {
        let open: Set<String> = ["10-neko-cat"]
        #expect(
            UsageSignal(.buddyPicked(buddyID: "10-neko-cat"))?.hidingBuddy(unlessIn: open)
                == UsageSignal(name: "Buddy.picked", parameters: ["buddy": "10-neko-cat"]))
        #expect(
            UsageSignal(.buddyPicked(buddyID: "40-secret-buddy"))?.hidingBuddy(unlessIn: open)
                == UsageSignal(name: "Buddy.picked", parameters: ["buddy": "locked"]))
        #expect(
            UsageSignal(.setupFinished(buddyID: "40-secret-buddy"))?.hidingBuddy(unlessIn: open)
                == UsageSignal(name: "Setup.finished", parameters: ["buddy": "locked"]))
        #expect(UsageSignal(.appStarted)?.hidingBuddy(unlessIn: open) == UsageSignal(name: "App.started"))
    }

    @Test("Counts go only with an app id, after setup, with the switch on")
    func policy() {
        #expect(UsagePolicy.canSend(appID: "ABC", setupFinished: true, enabled: true))
        #expect(!UsagePolicy.canSend(appID: nil, setupFinished: true, enabled: true))
        #expect(!UsagePolicy.canSend(appID: "  ", setupFinished: true, enabled: true))
        #expect(!UsagePolicy.canSend(appID: "ABC", setupFinished: false, enabled: true))
        #expect(!UsagePolicy.canSend(appID: "ABC", setupFinished: true, enabled: false))
    }
}
