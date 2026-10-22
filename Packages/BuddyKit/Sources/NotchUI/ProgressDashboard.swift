import AppKit
import BuddyCore
import SwiftUI

/// One saved progress photo, for the photo strip.
public struct ProgressPhotoItem: Identifiable, Sendable {
    public let photo: ProgressPhoto
    public let url: URL
    public var id: URL { url }

    public init(photo: ProgressPhoto, url: URL) {
        self.photo = photo
        self.url = url
    }
}

/// The Progress window: the buddy and its level, today, this week, the 5 forms and the photos.
///
///     ┌───────────────────────────────────────────────┐
///     │ [buddy]  Pip · Level 4                        │
///     │          ███████░░░░  120 of 450 XP           │
///     │          🔥 3 days in a row · 2 of 5 this week │
///     │ Today    [score] [checks] [breaks] [time]     │
///     │ This week  [score chart] [breaks] [hours]     │
///     │ Forms    ● ● ◌ ◌ ◌                            │
///     │ Photos   ▢ ▢ ▢ ▢ (when on)                    │
///     └───────────────────────────────────────────────┘
public struct ProgressDashboard: View {
    let summary: ProgressSummary

    public init(
        appearance: BuddyAppearance, state: ProgressState, now: Date = Date(), calendar: Calendar = .current,
        photos: [ProgressPhotoItem]?, message: String? = nil, onDeleteHistory: @escaping () -> Void
    ) {
        summary = ProgressSummary(
            appearance: appearance, state: state, now: now, calendar: calendar, photos: photos, message: message,
            onDeleteHistory: onDeleteHistory)
    }

    public var body: some View {
        ScrollView { summary }
    }
}

/// The Progress window without its scroll view, so tests can draw it off screen.
struct ProgressSummary: View {
    let appearance: BuddyAppearance
    let state: ProgressState
    let now: Date
    let calendar: Calendar
    /// Nil when progress photos are off.
    let photos: [ProgressPhotoItem]?
    let message: String?
    let onDeleteHistory: () -> Void
    @State private var confirmsDelete = false

    private var today: DayTotals { state.totals(on: now, calendar: calendar) ?? .empty(on: now, calendar: calendar) }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            header
            if let message {
                Label(message, systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            }
            section("Today") { todayTiles }
            section("This week") { WeekCharts(week: state.week(of: now, calendar: calendar), calendar: calendar) }
            section("Forms") { forms }
            if let photos {
                section("Progress photos") { PhotoStrip(photos: photos) }
            }
            footer
        }
        .padding(24)
    }

    // MARK: - Buddy and level

    private var header: some View {
        HStack(alignment: .center, spacing: 20) {
            BuddySpriteView(appearance: appearance, mood: .happy, height: 110)
            VStack(alignment: .leading, spacing: 8) {
                Text("\(appearance.name) · Level \(state.level)").font(.title2.bold())
                let progress = state.levelProgress
                XPBar(fraction: Double(progress.gained) / Double(max(progress.needed, 1)))
                    .frame(width: 280)
                Text("\(progress.gained) of \(progress.needed) XP to level \(state.level + 1)")
                    .font(.callout).foregroundStyle(.secondary).monospacedDigit()
                HStack(spacing: 14) {
                    let streak = state.streak(at: now, calendar: calendar)
                    Label(Self.streakText(streak), systemImage: "flame.fill")
                        .foregroundStyle(streak > 0 ? Color.orange : Color.secondary)
                    Label(
                        "\(state.goalDaysInWeek(of: now, calendar: calendar)) of "
                            + "\(Progression.goalDaysForWeeklyGoal) goal days this week",
                        systemImage: "calendar")
                }
                .font(.callout)
            }
        }
    }

    // MARK: - Today

    private var todayTiles: some View {
        HStack(spacing: 12) {
            Tile(
                title: "Posture score", value: today.score.map(String.init) ?? "–",
                detail: today.goalReached ? "Goal reached" : "Goal: \(DayTotals.goalScore)")
            Tile(
                title: "Good checks", value: "\(today.goodChecks)",
                detail: "of \(today.knownChecks) checks")
            Tile(title: "Breaks", value: "\(today.breaksFinished)", detail: "finished")
            Tile(title: "At the Mac", value: Self.duration(today.secondsAtMac), detail: "today")
        }
    }

    static func streakText(_ streak: Int) -> String {
        switch streak {
        case 0: "No streak yet"
        case 1: "1 goal day"
        default: "\(streak) goal days in a row"
        }
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        return minutes < 60 ? "\(minutes) m" : "\(minutes / 60) h \(minutes % 60) m"
    }

    // MARK: - Forms

    private var forms: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(Array(BuddyAssets.forms), id: \.self) { form in
                let unlocked = form <= state.form
                VStack(spacing: 6) {
                    BuddySpriteView(
                        appearance: BuddyAppearance(
                            buddyID: appearance.buddyID, name: appearance.name, color: appearance.color, form: form),
                        mood: .happy, height: 64, animates: false
                    )
                    .colorMultiply(unlocked ? .white : .black)
                    .opacity(unlocked ? 1 : 0.35)
                    Text(formCaption(form))
                        .font(.caption.weight(form == state.form ? .semibold : .regular))
                        .foregroundStyle(form == state.form ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Form \(form), " + (unlocked ? "reached" : formCaption(form).lowercased())))
            }
        }
    }

    /// "Now" for the current form, "Form 2" for an earlier one, "Level 10" for a locked one.
    private func formCaption(_ form: Int) -> String {
        if form == state.form { return "Now" }
        return form < state.form ? "Form \(form)" : "Level \(Progression.levelForForm(form))"
    }

    // MARK: - Layout

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
    }

    private var footer: some View {
        HStack {
            Text("Your history stays on this Mac.").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Delete history…", role: .destructive) { confirmsDelete = true }
                .confirmationDialog("Delete all history?", isPresented: $confirmsDelete) {
                    Button("Delete history", role: .destructive, action: onDeleteHistory)
                } message: {
                    Text(
                        "Scores, checks, breaks, the streak and the level go back to the start. "
                            + "This cannot be undone.")
                }
        }
    }
}

/// A rounded bar that fills from the left. Drawn in SwiftUI, so it also draws off screen.
struct XPBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))
                Capsule().fill(Color.accentColor)
                    .frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityValue(Text("\(Int((fraction * 100).rounded())) percent"))
    }
}

/// One number for today, with a title above and a short line under it.
struct Tile: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title.bold()).monospacedDigit()
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.1)))
        .accessibilityElement(children: .combine)
    }
}
