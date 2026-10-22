import Foundation
import Testing

@testable import BuddyCore

@Suite("ReminderRules")
struct ReminderRulesTests {
    private let defaults = Reminder.defaults

    @Test("Text is trimmed and cut, an empty title gets a default")
    func cleansText() {
        let long = String(repeating: "a", count: 60)
        let reminder = Reminder(
            kind: .custom, title: "  \(long)  ", message: String(repeating: "b", count: 200), interval: 600)
        let cleaned = ReminderRules.cleaned(reminder)
        #expect(cleaned.title.count == ReminderRules.titleLimit)
        #expect(cleaned.message.count == ReminderRules.messageLimit)

        let empty = ReminderRules.cleaned(reminder.with(title: "   ", message: "  "))
        #expect(empty.title == "Reminder")
        #expect(empty.message == "")
        let stand = ReminderRules.cleaned(defaults[0].with(title: ""))
        #expect(stand.title == "Stand up")
    }

    @Test("Times are kept inside the limits")
    func clampsTimes() {
        let reminder = defaults[0]
        #expect(ReminderRules.cleaned(reminder.with(interval: 10)).interval == 60)
        #expect(ReminderRules.cleaned(reminder.with(interval: 999 * 60)).interval == 240 * 60)
        #expect(ReminderRules.cleaned(reminder.with(breakDuration: 3600)).breakDuration == 15 * 60)
        #expect(ReminderRules.cleaned(reminder.with(interval: 90.4 * 60)).interval == 90 * 60)
        #expect(ReminderRules.cleaned(reminder.with(breakDuration: 20.6)).breakDuration == 21)
    }

    @Test("An unknown routine id is dropped")
    func dropsUnknownRoutine() {
        #expect(ReminderRules.cleaned(defaults[0].withRoutine("gone")).routineID == nil)
        #expect(ReminderRules.cleaned(defaults[0].withRoutine("back")).routineID == "back")
    }

    @Test("Adding a reminder returns a new list; the old one does not change")
    func adding() {
        let custom = ReminderRules.newCustom()
        let list = ReminderRules.adding(custom, to: defaults)
        #expect(list.count == defaults.count + 1)
        #expect(list.last?.id == custom.id)
        #expect(defaults.count == 4)
        // The same id twice is not added.
        #expect(ReminderRules.adding(custom, to: list) == list)
    }

    @Test("At most 20 reminders")
    func limit() {
        let full = (0..<ReminderRules.maxReminders).reduce(defaults) { list, _ in
            ReminderRules.adding(ReminderRules.newCustom(), to: list)
        }
        #expect(full.count == ReminderRules.maxReminders)
        #expect(!ReminderRules.canAdd(to: full))
        #expect(ReminderRules.canAdd(to: defaults))
    }

    @Test("Updating keeps the place, the id and the kind")
    func updating() {
        let changed = defaults[1].with(title: "Eyes", interval: 25 * 60)
        let list = ReminderRules.updating(changed, in: defaults)
        #expect(list[1].title == "Eyes")
        #expect(list[1].interval == 25 * 60)
        #expect(list[1].id == defaults[1].id)
        #expect(list.count == defaults.count)
        // A reminder that is not in the list changes nothing.
        #expect(ReminderRules.updating(ReminderRules.newCustom(), in: defaults) == defaults)
    }

    @Test("Only custom reminders can be deleted")
    func deleting() {
        let custom = ReminderRules.newCustom()
        let list = ReminderRules.adding(custom, to: defaults)
        #expect(ReminderRules.deleting(custom.id, from: list) == defaults)
        #expect(ReminderRules.deleting(defaults[0].id, from: list) == list)
    }

    @Test("Reset brings back the built-in reminders and keeps the custom ones")
    func resetting() {
        let custom = ReminderRules.newCustom()
        let edited = ReminderRules.updating(defaults[0].with(interval: 99 * 60, isEnabled: false), in: defaults)
        let withoutWater = ReminderRules.adding(custom, to: Array(edited.dropLast()))
        let reset = ReminderRules.resettingBuiltIns(withoutWater)

        #expect(reset.map(\.kind) == [.standUp, .eyeRest, .stretch, .drinkWater, .custom])
        #expect(reset[0].interval == 30 * 60)
        #expect(reset[0].isEnabled)
        #expect(reset[0].id == defaults[0].id)  // the same reminder, so its progress is kept
        #expect(reset[4] == custom)
    }

    @Test("A new custom reminder is valid and off-the-shelf")
    func newCustom() {
        let custom = ReminderRules.newCustom()
        #expect(custom.kind == .custom)
        #expect(custom == ReminderRules.cleaned(custom))
        #expect(custom.isEnabled)
    }

    @Test("The routine is saved, and old saved reminders without one still load")
    func routineCoding() throws {
        let reminder = defaults[0].withRoutine("back")
        let data = try JSONEncoder().encode(reminder)
        #expect(try JSONDecoder().decode(Reminder.self, from: data) == reminder)

        let old = #"{"kind":"standUp","title":"Stand","message":"Up","interval":1800}"#
        let decoded = try JSONDecoder().decode(Reminder.self, from: Data(old.utf8))
        #expect(decoded.routineID == nil)
    }
}
