import Foundation
import Testing

@testable import BuddyCore

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Karachi")!
    calendar.firstWeekday = 2  // Monday
    return calendar
}()

/// 2026-10-19 is a Monday.
private func day(_ number: Int) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 10, day: number))!
}

private func goalDay(_ number: Int) -> DayTotals {
    DayTotals(day: day(number), goodChecks: 20, knownChecks: 20, goalReached: true)
}

@Suite("DayTotals")
struct DayTotalsTests {
    @Test("Checks, breaks, reminders and time add up; unknown checks do not count")
    func adds() {
        let totals = DayTotals.empty(on: day(22).addingTimeInterval(3600), calendar: calendar)
            .recording(.good)
            .recording(.slouching([.headDropped]))
            .recording(.unknown)
            .recordingBreakFinished()
            .recordingReminderDone()
            .addingTimeAtMac(90)
        #expect(totals.day == day(22))
        #expect(totals.goodChecks == 1)
        #expect(totals.knownChecks == 2)
        #expect(totals.score == 50)
        #expect(totals.breaksFinished == 1)
        #expect(totals.remindersDone == 1)
        #expect(totals.secondsAtMac == 90)
    }

    @Test("The daily goal needs a score of 70 and at least 10 checks, and stays reached")
    func goal() {
        var totals = DayTotals.empty(on: day(22), calendar: calendar)
        for _ in 0..<9 { totals = totals.recording(.good) }
        #expect(!totals.goalReached)  // 9 checks are not enough
        totals = totals.recording(.good)
        #expect(totals.goalReached)
        for _ in 0..<20 { totals = totals.recording(.slouching([.leaningIn])) }
        #expect(totals.score! < 70)
        #expect(totals.goalReached)  // a reached goal is not taken back
    }

    @Test("No known check: no score")
    func noScore() {
        #expect(DayTotals.empty(on: day(22), calendar: calendar).score == nil)
    }
}

@Suite("Progression")
struct ProgressionTests {
    @Test("XP: 1 for a good check, 10 for a finished break, 25 for a goal day")
    func xp() {
        let days = [
            DayTotals(day: day(20), goodChecks: 30, knownChecks: 40, breaksFinished: 2, goalReached: true),
            DayTotals(day: day(21), goodChecks: 5, knownChecks: 9),
        ]
        #expect(ProgressState(days: days).xp == 30 + 20 + 25 + 5)
    }

    @Test("Levels grow slower as they go up")
    func levels() {
        #expect(Progression.level(forXP: 0) == 1)
        #expect(Progression.level(forXP: 149) == 1)
        #expect(Progression.level(forXP: 150) == 2)
        #expect(Progression.level(forXP: 600) == 3)
        #expect(Progression.xpToReach(level: 10) == 150 * 81)
        #expect(Progression.level(forXP: Progression.xpToReach(level: 10)) == 10)
        #expect(Progression.level(forXP: Progression.xpToReach(level: 10) - 1) == 9)
    }

    @Test("A new buddy is a baby (form 1) and grows at levels 3, 6, 10 and 15")
    func forms() {
        #expect(Progression.form(forLevel: 1) == 1)
        #expect(Progression.form(forLevel: 2) == 1)
        #expect(Progression.form(forLevel: 3) == 2)
        #expect(Progression.form(forLevel: 6) == 3)
        #expect(Progression.form(forLevel: 10) == 4)
        #expect(Progression.form(forLevel: 15) == 5)
        #expect(Progression.form(forLevel: 99) == 5)
        #expect(Progression.levelForForm(3) == 6)
    }

    @Test("Streak: goal days in a row; today counts once reached, a gap ends it")
    func streak() {
        let state = ProgressState(days: [goalDay(18), goalDay(20), goalDay(21)])
        #expect(state.streak(at: day(22), calendar: calendar) == 2)  // today not reached yet
        let reached = state.updating(goalDay(22))
        #expect(reached.streak(at: day(22), calendar: calendar) == 3)
        #expect(state.streak(at: day(24), calendar: calendar) == 0)  // yesterday (23rd) has no data
    }

    @Test("Goal days this week start on the calendar's first weekday")
    func week() {
        let state = ProgressState(days: [goalDay(18), goalDay(19), goalDay(20), goalDay(21)])
        #expect(state.goalDaysInWeek(of: day(22), calendar: calendar) == 3)  // the 18th is last week's Sunday
    }

    @Test("The week has 7 days from the first weekday; days with no data are empty")
    func weekDays() {
        let week = ProgressState(days: [goalDay(18), goalDay(20)]).week(of: day(22), calendar: calendar)
        #expect(week.map(\.day) == (19...25).map(day))
        #expect(week[1] == goalDay(20))
        #expect(week[0] == DayTotals(day: day(19)))
    }

    @Test("Level progress: XP into this level, and XP this level needs")
    func levelProgress() {
        let state = ProgressState(days: [DayTotals(day: day(22), goodChecks: 200, knownChecks: 200)])
        #expect(state.level == 2)
        #expect(state.levelProgress.gained == 50)
        #expect(state.levelProgress.needed == 450)
    }

    @Test("Updating a day replaces it and keeps the days in order")
    func updating() {
        let state = ProgressState(days: [goalDay(21)]).updating(goalDay(19)).updating(goalDay(21))
        #expect(state.days.map(\.day) == [day(19), day(21)])
    }
}

@Suite("Progress milestones")
struct ProgressMilestoneTests {
    @Test("The first goal of the day is a daily goal, or a streak after another goal day")
    func goalMilestones() {
        let before = ProgressState(days: [DayTotals(day: day(22), goodChecks: 9, knownChecks: 9)])
        let after = before.updating(DayTotals(day: day(22), goodChecks: 10, knownChecks: 10, goalReached: true))
        #expect(Progression.milestones(from: before, to: after, at: day(22), calendar: calendar) == [.dailyGoal])

        let withYesterday = ProgressState(days: [goalDay(21)] + before.days)
        let streak = withYesterday.updating(goalDay(22))
        #expect(
            Progression.milestones(from: withYesterday, to: streak, at: day(22), calendar: calendar) == [.streak(2)])
        // Nothing new: no milestone.
        #expect(Progression.milestones(from: streak, to: streak, at: day(22), calendar: calendar).isEmpty)
    }

    @Test("The fifth goal day of the week is the weekly goal")
    func weeklyGoal() {
        let before = ProgressState(days: [goalDay(19), goalDay(20), goalDay(21), goalDay(22)])
        let after = before.updating(goalDay(23))
        let milestones = Progression.milestones(from: before, to: after, at: day(23), calendar: calendar)
        #expect(milestones.contains(.weeklyGoal))
    }

    @Test("A new level is a level up; a new form is a grow up")
    func levelMilestones() {
        let start = ProgressState(days: [DayTotals(day: day(22), goodChecks: 140, knownChecks: 140)])
        let level2 = start.updating(DayTotals(day: day(22), goodChecks: 150, knownChecks: 150))
        #expect(Progression.milestones(from: start, to: level2, at: day(22), calendar: calendar) == [.levelUp(2)])

        let nearForm2 = ProgressState(days: [DayTotals(day: day(22), goodChecks: 599, knownChecks: 599)])
        let form2 = nearForm2.updating(DayTotals(day: day(22), goodChecks: 600, knownChecks: 600))
        #expect(Progression.milestones(from: nearForm2, to: form2, at: day(22), calendar: calendar) == [.grewUp(2)])
    }
}
