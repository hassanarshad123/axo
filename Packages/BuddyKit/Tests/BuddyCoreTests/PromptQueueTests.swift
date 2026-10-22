import Foundation
import Testing

@testable import BuddyCore

private let stand = BuddyPrompt(id: "stand", title: "Stand up", message: "Move")
private let eyes = BuddyPrompt(id: "eyes", title: "Rest your eyes", message: "Look far away")
private let water = BuddyPrompt(id: "water", title: "Drink water", message: "Sip")

@Suite("PromptQueue")
struct PromptQueueTests {
    @Test func firstPromptOpensTheIsland() {
        let queue = PromptQueue().adding(stand, currentIsOnScreen: false)
        #expect(queue.current == stand)
        #expect(queue.shouldOpen)
    }

    @Test("A new prompt never replaces one the user has not answered")
    func newPromptWaits() {
        let queue = PromptQueue()
            .adding(stand, currentIsOnScreen: false)
            .adding(eyes, currentIsOnScreen: true)
        #expect(queue.current == stand)
        #expect(queue.count == 2)
    }

    @Test("The same prompt is queued only once")
    func noDuplicates() {
        let queue = PromptQueue()
            .adding(stand, currentIsOnScreen: false)
            .adding(stand, currentIsOnScreen: true)
        #expect(queue.count == 1)
    }

    @Test("Done or Snooze shows the next prompt")
    func answeringShowsNext() {
        let queue = PromptQueue()
            .adding(stand, currentIsOnScreen: false)
            .adding(eyes, currentIsOnScreen: true)
            .answeringCurrent()
        #expect(queue.current == eyes)
        #expect(queue.shouldOpen)
        #expect(queue.answeringCurrent().isEmpty)
    }

    @Test("An auto-closed prompt waits at the back and the next new prompt opens")
    func autoCloseShowsNextFreshPrompt() {
        let queue = PromptQueue()
            .adding(stand, currentIsOnScreen: false)
            .adding(eyes, currentIsOnScreen: true)
            .autoClosingCurrent()
        #expect(queue.current == eyes)
        #expect(queue.shouldOpen)
        #expect(queue.entries.last == PromptQueue.Entry(prompt: stand, autoClosed: true))
    }

    @Test("When every prompt has auto-closed once, the island stays closed (a dot shows)")
    func allAutoClosedStaysClosed() {
        let queue = PromptQueue().adding(stand, currentIsOnScreen: false).autoClosingCurrent()
        #expect(queue.current == stand)
        #expect(!queue.shouldOpen)
        #expect(queue.count == 1)
    }

    @Test("A new prompt goes ahead of prompts that already auto-closed")
    func freshPromptGoesFirst() {
        let queue = PromptQueue()
            .adding(stand, currentIsOnScreen: false)
            .autoClosingCurrent()
            .adding(eyes, currentIsOnScreen: false)
        #expect(queue.current == eyes)
        #expect(queue.shouldOpen)
    }

    @Test("A prompt the user is looking at (hover) is not pushed away")
    func onScreenPromptStays() {
        let queue = PromptQueue()
            .adding(stand, currentIsOnScreen: false)
            .autoClosingCurrent()
            .adding(eyes, currentIsOnScreen: true)
        #expect(queue.current == stand)
        #expect(queue.count == 2)
    }

    @Test("Prompts can be taken back, for example after the user took a break")
    func removingPrompts() {
        let queue = PromptQueue()
            .adding(stand, currentIsOnScreen: false)
            .adding(eyes, currentIsOnScreen: true)
            .adding(water, currentIsOnScreen: true)
            .removing(ids: [stand.id, eyes.id])
        #expect(queue.current == water)
        #expect(queue.count == 1)
    }

    @Test func reminderPromptCarriesTheReminder() {
        let reminder = Reminder(kind: .standUp, title: "Stand up", message: "Move", interval: 60)
        let prompt = BuddyPrompt.reminder(reminder)
        #expect(prompt.reminderID == reminder.id)
        #expect(prompt.id == reminder.id.uuidString)
        #expect(prompt.title == "Stand up")
    }

    @Test("A reminder prompt shows the reminder's pose and the normal buttons")
    func reminderPrompt() {
        let eyes = Reminder.defaults[1]
        let prompt = BuddyPrompt.reminder(eyes)
        #expect(prompt.id == eyes.id.uuidString)
        #expect(prompt.pose == "eyes")
        #expect(prompt.doneTitle == "Done")
        #expect(prompt.canSnooze)
        #expect(BuddyPrompt.reminder(Reminder.defaults[0]).pose == "walk")
        #expect(BuddyPrompt(title: "Sit tall", message: "Lift your head").pose == nil)
    }

    @Test("A break notice has the same id as the reminder, so it is queued only once")
    func breakNotice() {
        let stretch = Reminder.defaults[2]
        let locked = BuddyPrompt.breakNotice(stretch, in: 10, canSnooze: false)
        #expect(locked.id == BuddyPrompt.noticeID(for: stretch.id))
        #expect(locked.reminderID == stretch.id)
        #expect(locked.doneTitle == "Start now")
        #expect(!locked.canSnooze)
        #expect(locked.message.hasSuffix("A full-screen break starts in 10 seconds."))
        #expect(BuddyPrompt.breakNotice(stretch, in: 10, canSnooze: true).canSnooze)
    }

    @Test("A break notice is never dropped because the same reminder's prompt still waits")
    func noticeIsNotDropped() {
        let stretch = Reminder.defaults[2]
        let notice = BuddyPrompt.breakNotice(stretch, in: 30, canSnooze: false)
        let queue = PromptQueue()
            .adding(.reminder(stretch), currentIsOnScreen: false)
            .adding(notice, currentIsOnScreen: false)
        #expect(queue.count == 2)
        #expect(notice.id != BuddyPrompt.reminder(stretch).id)
    }

    @Test("A grow-up prompt names the buddy, celebrates, and has one id per form")
    func grewUp() {
        let prompt = BuddyPrompt.grewUp(name: "Pip", form: 3)
        #expect(prompt.title == "Pip grew up!")
        #expect(prompt.pose == "celebrate")
        #expect(!prompt.canSnooze)
        #expect(prompt.id != BuddyPrompt.grewUp(name: "Pip", form: 4).id)
    }
}
