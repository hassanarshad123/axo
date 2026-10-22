import BuddyCore
import SwiftUI

/// A gentle break inside the island: the buddy does the step, the text says how, a countdown runs.
///
///     ┌───────────────────────────────────────┐
///     │ ┌──────┐  STRETCH · 2 of 6     1:12   │
///     │ │buddy │  Now tilt your head to the   │
///     │ │ step │  right.                       │
///     │ └──────┘  ▓▓▓▓▓▓░░░░░░░░   [End]       │
///     └───────────────────────────────────────┘
struct BreakIslandView: View {
    let session: BreakSession
    let appearance: BuddyAppearance
    let buddyHeight: CGFloat
    let onEnd: () -> Void

    var body: some View {
        TimelineView(.periodic(from: session.startedAt, by: 1)) { context in
            content(session.state(at: context.date))
        }
    }

    private func content(_ state: BreakSession.State) -> some View {
        HStack(alignment: .top, spacing: 14) {
            BuddySpriteView(appearance: appearance, mood: .stretching, height: buddyHeight, pose: state.pose)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(heading(state))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Text(BreakSession.clockText(state.secondsLeft))
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                }
                Text(state.instruction)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(3)
                HStack(spacing: 10) {
                    ProgressBar(value: state.progress)
                    Button("End", action: onEnd)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                .padding(.top, 2)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func heading(_ state: BreakSession.State) -> String {
        let title = session.title.uppercased()
        guard let index = state.stepIndex, session.steps.count > 1 else { return title }
        return "\(title) · \(index + 1) of \(session.steps.count)"
    }
}

/// A thin bar drawn in SwiftUI. The system bar is an AppKit control and does not draw off screen.
private struct ProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.18))
                Capsule()
                    .fill(.white.opacity(0.85))
                    .frame(width: proxy.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 5)
        .accessibilityValue(Text("\(Int((value * 100).rounded())) percent"))
    }
}
