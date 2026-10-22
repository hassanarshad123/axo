import BuddyCore
import Observation
import SwiftUI

/// What every break screen shows. One model drives the panels on all screens.
@MainActor
@Observable
final class BreakScreenModel {
    let session: BreakSession
    let appearance: BuddyAppearance
    /// When the user started to hold Esc or the "Hold to leave" button. Nil = not held.
    var exitHeldSince: Date?

    init(session: BreakSession, appearance: BuddyAppearance) {
        self.session = session
        self.appearance = appearance
    }
}

/// The full-screen break.
///
///                    NECK AND SHOULDERS
///                       [  buddy  ]
///           Now tilt your head to the right.
///                  Step 2 of 6 · 0:12
///                       ( 1:14 )            countdown ring
///             [Skip break]  or  [Hold to leave]
struct BreakScreenView: View {
    @Bindable var model: BreakScreenModel
    let onSkip: () -> Void
    let onExit: () -> Void

    private var session: BreakSession { model.session }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.13, green: 0.09, blue: 0.22), Color(red: 0.05, green: 0.06, blue: 0.13)],
                startPoint: .top, endPoint: .bottom
            )
            .opacity(0.97)
            TimelineView(.periodic(from: session.startedAt, by: 0.5)) { context in
                content(session.state(at: context.date))
            }
            .padding(40)
        }
        .ignoresSafeArea()
        .foregroundStyle(.white)
    }

    private func content(_ state: BreakSession.State) -> some View {
        VStack(spacing: 22) {
            Text(session.title.uppercased())
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.6))
            BuddySpriteView(appearance: model.appearance, mood: .stretching, height: 220, pose: state.pose)
            Text(state.instruction)
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 760)
                .fixedSize(horizontal: false, vertical: true)
            if let index = state.stepIndex, session.steps.count > 1 {
                Text("Step \(index + 1) of \(session.steps.count) · \(BreakSession.clockText(state.stepSecondsLeft))")
                    .font(.system(size: 17, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.7))
            }
            CountdownRing(progress: state.progress, text: BreakSession.clockText(state.secondsLeft))
                .frame(width: 150, height: 150)
            footer
        }
    }

    @ViewBuilder
    private var footer: some View {
        if session.canSkip {
            Button("Skip break", action: onSkip)
                .buttonStyle(.bordered)
                .controlSize(.large)
            Text("Or press Esc.")
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
        } else {
            HoldToLeave(model: model, onExit: onExit)
        }
    }
}

/// The way out of a locked break: hold the button, or Esc, for 3 seconds. Nobody is ever trapped.
private struct HoldToLeave: View {
    @Bindable var model: BreakScreenModel
    let onExit: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("Hold to leave")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(Capsule().fill(.white.opacity(0.12)))
                .onLongPressGesture(
                    minimumDuration: BreakSession.emergencyExitHold,
                    perform: onExit,
                    onPressingChanged: { pressing in model.exitHeldSince = pressing ? Date() : nil }
                )
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Hold for 3 seconds to end the break")
            if let since = model.exitHeldSince {
                TimelineView(.periodic(from: since, by: 0.1)) { context in
                    ProgressView(
                        value: BreakSession.emergencyExitProgress(heldFor: context.date.timeIntervalSince(since))
                    )
                    .progressViewStyle(.linear)
                    .tint(.white)
                    .frame(width: 160)
                }
            } else {
                Text("Or hold Esc for 3 seconds.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}

private struct CountdownRing: View {
    let progress: Double
    let text: String

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.15), lineWidth: 10)
            Circle()
                .trim(from: 0, to: max(0, 1 - progress))
                .stroke(.white, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.5), value: progress)
            Text(text)
                .font(.system(size: 38, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .accessibilityElement()
        .accessibilityLabel(Text("\(text) left"))
    }
}
