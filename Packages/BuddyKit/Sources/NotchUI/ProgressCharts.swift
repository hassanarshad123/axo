import BuddyCore
import Charts
import SwiftUI

/// This week in 3 small bar charts: posture score (with the goal line), finished breaks, hours at the Mac.
///
///     score         breaks        hours
///     ▂▅█▇ ─70─     ▁▃▂▅          ▃▆▅▇
///     Mon … Sun     Mon … Sun     Mon … Sun
struct WeekCharts: View {
    let week: [DayTotals]
    let calendar: Calendar

    /// "Mon", "Tue"...: one name per day, so the axis shows the whole week, also the days to come.
    private func label(_ day: DayTotals) -> String {
        calendar.shortWeekdaySymbols[calendar.component(.weekday, from: day.day) - 1]
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            chart("Posture score", unit: "out of 100") {
                ForEach(week, id: \.day) { day in
                    if let score = day.score {
                        BarMark(x: .value("Day", label(day)), y: .value("Score", score))
                            .foregroundStyle(day.goalReached ? Color.green : Color.accentColor)
                    }
                }
                RuleMark(y: .value("Goal", DayTotals.goalScore))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.secondary)
            }
            .chartYScale(domain: 0...100)
            chart("Breaks", unit: "finished") {
                ForEach(week, id: \.day) { day in
                    BarMark(x: .value("Day", label(day)), y: .value("Breaks", day.breaksFinished))
                        .foregroundStyle(Color.orange)
                }
            }
            chart("At the Mac", unit: "hours") {
                ForEach(week, id: \.day) { day in
                    BarMark(x: .value("Day", label(day)), y: .value("Hours", day.secondsAtMac / 3600))
                        .foregroundStyle(Color.teal)
                }
            }
        }
    }

    private func chart(
        _ title: String, unit: String, @ChartContentBuilder content: () -> some ChartContent
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(unit).font(.caption).foregroundStyle(.secondary)
            }
            Chart(content: content)
                .chartXScale(domain: week.map(label))
                .frame(height: 120)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(title) this week"))
    }
}
