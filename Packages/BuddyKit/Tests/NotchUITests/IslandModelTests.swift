import BuddyCore
import Foundation
import Testing

@testable import NotchUI

@Suite("IslandModel")
@MainActor
struct IslandModelTests {
    private let stand = IslandModel.Prompt(title: "Stand up", message: "Move a little")
    private let eyes = IslandModel.Prompt(title: "Rest your eyes", message: "Look far away")

    private func model(collapseAfter: Duration = .seconds(60), hoverDelay: Duration = .zero) -> IslandModel {
        IslandModel(autoCollapseDelay: collapseAfter, hoverDelay: hoverDelay)
    }

    @Test func startsCompact() {
        let model = model()
        #expect(model.presentation == .compact)
        #expect(!model.isExpanded)
        #expect(model.prompt == nil)
        #expect(!model.hasWaitingPrompt)
    }

    @Test func showingAPromptExpands() {
        let model = model()
        model.show(stand)
        #expect(model.isExpanded)
        #expect(model.prompt?.title == "Stand up")

        model.dismissPrompt()
        #expect(!model.isExpanded)
        #expect(model.prompt == nil)
    }

    @Test("A second prompt waits until the first is answered")
    func secondPromptWaits() {
        let model = model()
        model.show(stand)
        model.show(eyes)
        #expect(model.prompt == stand)
        #expect(model.waitingCount == 1)

        model.dismissPrompt()
        #expect(model.prompt == eyes)
        #expect(model.isExpanded)
    }

    @Test func hoverExpandsWithoutAPrompt() {
        let model = model()
        model.hoverChanged(true)
        #expect(model.isExpanded)
        #expect(model.presentation == .compact)
        model.hoverChanged(false)
        #expect(!model.isExpanded)
    }

    @Test("Hover opens the island only after a short wait")
    func hoverWaits() async throws {
        let model = model(hoverDelay: .milliseconds(50))
        model.hoverChanged(true)
        #expect(!model.isExpanded)
        try await Task.sleep(for: .milliseconds(400))
        #expect(model.isExpanded)
    }

    @Test("Passing the pointer over the island quickly does not open it")
    func quickHoverDoesNothing() async throws {
        let model = model(hoverDelay: .milliseconds(300))
        model.hoverChanged(true)
        // No sleep here: other tests can block the main actor for longer than the hover delay.
        model.hoverChanged(false)
        try await Task.sleep(for: .milliseconds(500))
        #expect(!model.isExpanded)
    }

    @Test("An unanswered prompt closes by itself and leaves a dot")
    func unansweredPromptCollapses() async throws {
        let model = model(collapseAfter: .milliseconds(50))
        model.show(stand)
        try await Task.sleep(for: .milliseconds(500))
        #expect(model.presentation == .compact)
        #expect(model.prompt == stand)
        #expect(model.hasWaitingPrompt)
    }

    @Test("After every prompt closed once, both still wait and the island stays small")
    func everyPromptGetsItsTurn() async throws {
        let model = model(collapseAfter: .milliseconds(40))
        model.show(stand)
        model.show(eyes)
        try await Task.sleep(for: .milliseconds(800))
        #expect(model.presentation == .compact)
        #expect(model.waitingCount == 1)
        #expect(model.hasWaitingPrompt)
    }

    @Test("Prompts can be taken back")
    func withdrawingPrompts() {
        let model = model()
        model.show(stand)
        model.withdraw(ids: [stand.id])
        #expect(model.prompt == nil)
        #expect(!model.isExpanded)
    }

    @Test func startsWithAxo() {
        #expect(model().buddy == .axo)
    }

    @Test("Every mood has art for Axo, so the island never shows the fallback symbol")
    func everyMoodHasArt() {
        for mood in BuddyMood.allCases {
            let pose = BuddyAssets.pose(for: mood)
            let art = BuddySprites.shared.image(buddyID: BuddyCatalog.defaultBuddyID, color: .original, pose: pose)
            #expect(art != nil, "\(mood)")
        }
    }

    @Test("The idle schedule starts now and only moves forward")
    func idleScheduleMovesForward() {
        let schedule = IdleSchedule(animation: BuddyIdleAnimation(), canBlink: true)
        let start = Date(timeIntervalSinceReferenceDate: 1000.3)
        let times = Array(schedule.entries(from: start, mode: .normal).prefix(20))
        #expect(times.first == start)
        #expect(zip(times, times.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test("A gentle break fills the island; prompts wait behind it")
    func breakFillsTheIsland() throws {
        let model = model()
        let session = try #require(
            BreakSession(reminder: Reminder.defaults[2], style: .gentle, startedAt: Date()))
        model.startBreak(session)
        #expect(model.activeBreak == session)
        #expect(model.isExpanded)

        model.show(stand)
        #expect(model.activeBreak == session)  // the break stays on screen
        #expect(model.hasWaitingPrompt)

        model.endBreak()
        #expect(model.activeBreak == nil)
        #expect(model.prompt?.title == "Stand up")
        #expect(model.isExpanded)
    }

    @Test("A break that ends with nothing waiting closes the island")
    func breakEndsCompact() throws {
        let model = model()
        model.startBreak(try #require(BreakSession(reminder: Reminder.defaults[1], style: .gentle, startedAt: Date())))
        model.endBreak()
        #expect(!model.isExpanded)
    }

    @Test("A break never closes by itself like a prompt does")
    func breakDoesNotAutoClose() async throws {
        let model = model(collapseAfter: .milliseconds(50))
        model.show(stand)
        model.startBreak(try #require(BreakSession(reminder: Reminder.defaults[2], style: .gentle, startedAt: Date())))
        try await Task.sleep(for: .milliseconds(300))
        #expect(model.activeBreak != nil)
        #expect(model.isExpanded)
    }

    @Test("A moment shows its pose for a while, then the mood comes back")
    func momentShowsThenEnds() async throws {
        let model = IslandModel(momentDuration: .milliseconds(100))
        model.showMoment(.hello)
        #expect(model.momentPose == "wave")
        try await Task.sleep(for: .milliseconds(400))
        #expect(model.momentPose == nil)
    }

    @Test("The island draws the moment first, then the prompt's pose, then the mood")
    func poseOrder() throws {
        let model = model()
        model.mood = .worried
        #expect(model.pose == "worried")
        model.show(IslandModel.Prompt.reminder(Reminder.defaults[1]))
        #expect(model.pose == "eyes")
        model.showMoment(.goodJob)
        #expect(model.pose == "thumbs-up")
    }
}
