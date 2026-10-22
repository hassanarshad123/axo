import Foundation

/// Something worth a small celebration. The app shows a moment, a prompt or a voice line for each.
public enum ProgressMilestone: Sendable, Equatable {
    /// Today's goal is reached, and yesterday was not a goal day.
    case dailyGoal
    /// Today's goal is reached, and this many goal days are now in a row (2 or more).
    case streak(Int)
    /// The fifth goal day of this calendar week.
    case weeklyGoal
    /// A new level, with no new form.
    case levelUp(Int)
    /// A new level that also gives a new form (2 to 5).
    case grewUp(Int)
}

/// All saved days, oldest first, one value per day. XP, level, form and streak come from these.
public struct ProgressState: Sendable, Equatable {
    public let days: [DayTotals]

    public init(days: [DayTotals]) {
        self.days = days.sorted { $0.day < $1.day }
    }

    public static let empty = ProgressState(days: [])

    public var xp: Int { days.reduce(0) { $0 + Progression.xp(for: $1) } }
    public var level: Int { Progression.level(forXP: xp) }
    public var form: Int { Progression.form(forLevel: level) }

    /// The totals of the day that holds `date`, if any.
    public func totals(on date: Date, calendar: Calendar = .current) -> DayTotals? {
        let start = calendar.startOfDay(for: date)
        return days.last { $0.day == start }
    }

    /// Replaces the day with the same start, or adds it.
    public func updating(_ totals: DayTotals) -> ProgressState {
        ProgressState(days: days.filter { $0.day != totals.day } + [totals])
    }

    /// Goal days in a row up to today. Today counts once its goal is reached. Until then the
    /// streak counts from yesterday, so it does not drop to 0 each morning.
    public func streak(at date: Date, calendar: Calendar = .current) -> Int {
        let reachedToday = totals(on: date, calendar: calendar)?.goalReached ?? false
        let firstDay = reachedToday ? date : calendar.date(byAdding: .day, value: -1, to: date) ?? date
        var count = 0
        var day = firstDay
        while totals(on: day, calendar: calendar)?.goalReached == true {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    /// Goal days in the calendar week that holds `date`. The week starts on the calendar's first weekday.
    public func goalDaysInWeek(of date: Date, calendar: Calendar = .current) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date) else { return 0 }
        return days.filter { $0.goalReached && week.start <= $0.day && $0.day < week.end }.count
    }

    /// The 7 days of the calendar week that holds `date`, in order. A day with no data is empty.
    public func week(of date: Date, calendar: Calendar = .current) -> [DayTotals] {
        guard let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { return [] }
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start).map { day in
                totals(on: day, calendar: calendar) ?? .empty(on: day, calendar: calendar)
            }
        }
    }

    /// XP gained since the start of the current level, and XP the next level needs from there.
    public var levelProgress: (gained: Int, needed: Int) {
        let start = Progression.xpToReach(level: level)
        return (xp - start, Progression.xpToReach(level: level + 1) - start)
    }
}

/// The rules for XP, levels and forms.
///
///     XP:     1 a good check · 10 a finished break · 25 a goal day
///     level:  L needs 150 × (L − 1)² XP   →  level 2 at 150, 3 at 600, 10 at 12,150
///     form:   1 (baby) at level 1 · 2 at 3 · 3 at 6 · 4 at 10 · 5 at 15
///
/// A good 6-hour day is about 300 XP (about 250 good checks, 5 breaks, the goal). At that pace
/// form 2 comes on day 2, form 3 on day 13, form 4 on day 41 and form 5 after about 100 days.
public enum Progression {
    public static let xpPerGoodCheck = 1
    public static let xpPerFinishedBreak = 10
    public static let xpPerGoalDay = 25
    static let xpPerLevelStep = 150
    /// The first level of each form. Index 0 is form 1.
    static let formLevels = [1, 3, 6, 10, 15]
    public static let goalDaysForWeeklyGoal = 5

    public static var lastForm: Int { formLevels.count }

    public static func xp(for day: DayTotals) -> Int {
        day.goodChecks * xpPerGoodCheck + day.breaksFinished * xpPerFinishedBreak
            + (day.goalReached ? xpPerGoalDay : 0)
    }

    public static func xpToReach(level: Int) -> Int {
        let steps = max(level - 1, 0)
        return xpPerLevelStep * steps * steps
    }

    public static func level(forXP xp: Int) -> Int {
        // The square root gives a close guess. The loops fix rounding at exact squares.
        var level = Int((Double(max(xp, 0)) / Double(xpPerLevelStep)).squareRoot()) + 1
        while level > 1, xpToReach(level: level) > xp { level -= 1 }
        while xpToReach(level: level + 1) <= xp { level += 1 }
        return level
    }

    public static func form(forLevel level: Int) -> Int {
        formLevels.lastIndex { $0 <= level }.map { $0 + 1 } ?? 1
    }

    /// The level at which a form starts.
    public static func levelForForm(_ form: Int) -> Int {
        formLevels[min(max(form, 1), lastForm) - 1]
    }

    /// What changed from `before` to `after` that deserves a celebration, in the order to show it.
    public static func milestones(
        from before: ProgressState,
        to after: ProgressState,
        at date: Date,
        calendar: Calendar = .current
    ) -> [ProgressMilestone] {
        var found: [ProgressMilestone] = []
        let reachedBefore = before.totals(on: date, calendar: calendar)?.goalReached ?? false
        let reachedNow = after.totals(on: date, calendar: calendar)?.goalReached ?? false
        if reachedNow, !reachedBefore {
            let streak = after.streak(at: date, calendar: calendar)
            found.append(streak >= 2 ? .streak(streak) : .dailyGoal)
            let weekBefore = before.goalDaysInWeek(of: date, calendar: calendar)
            let weekNow = after.goalDaysInWeek(of: date, calendar: calendar)
            if weekBefore < goalDaysForWeeklyGoal, weekNow >= goalDaysForWeeklyGoal {
                found.append(.weeklyGoal)
            }
        }
        if after.level > before.level {
            found.append(after.form > before.form ? .grewUp(after.form) : .levelUp(after.level))
        }
        return found
    }
}
