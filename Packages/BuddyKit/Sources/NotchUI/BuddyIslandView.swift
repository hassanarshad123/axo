import BuddyCore
import SwiftUI

/// The black island that grows out of the notch.
///
///     compact:   [ buddy ]███notch███[ 12m ]     (buddy 26 pt tall)
///     waiting:   [ buddy• ]██notch███[ 12m ]     (a prompt closed by itself; hover to see it)
///     expanded:  ┌───────────────────────────────┐
///                │ ┌──────┐  AXO                 │
///                │ │buddy │  Stand up            │  (buddy 92 pt tall)
///                │ │      │  You have been ...   │
///                │ └──────┘  [Done]  [Snooze]    │
///                └───────────────────────────────┘
///     break:     the same size, with the stretch step and a countdown (`BreakIslandView`)
public struct BuddyIslandView: View {
    @Bindable var model: IslandModel

    public static let compactWingWidth: CGFloat = 64
    public static let expandedSize = CGSize(width: 440, height: 176)
    static let compactBuddyHeight: CGFloat = 26
    static let expandedBuddyHeight: CGFloat = 92

    public init(model: IslandModel) {
        self.model = model
    }

    public var body: some View {
        VStack(spacing: 0) {
            island
                .onHover { model.hoverChanged($0) }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: model.isExpanded)
    }

    private var island: some View {
        ZStack(alignment: .top) {
            IslandShape(bottomRadius: model.isExpanded ? 22 : 10)
                .fill(.black)
            if model.isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            } else {
                compactContent
                    .transition(.opacity)
            }
        }
        .frame(width: islandSize.width, height: islandSize.height)
    }

    private var islandSize: CGSize {
        if model.isExpanded { return Self.expandedSize }
        return CGSize(
            width: model.notchSize.width + Self.compactWingWidth * 2,
            height: model.notchSize.height
        )
    }

    private var compactContent: some View {
        HStack(spacing: 0) {
            BuddySpriteView(
                appearance: model.buddy,
                mood: model.mood,
                height: min(Self.compactBuddyHeight, model.notchSize.height - 4),
                pose: model.momentPose
            )
            .overlay(alignment: .topTrailing) {
                if model.hasWaitingPrompt {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                        .accessibilityLabel("A reminder is waiting")
                }
            }
            .frame(width: Self.compactWingWidth)
            Spacer(minLength: model.notchSize.width)
            Text(model.trailingText)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: Self.compactWingWidth)
        }
        .frame(height: model.notchSize.height)
    }

    @ViewBuilder
    private var expandedContent: some View {
        if let session = model.activeBreak {
            BreakIslandView(
                session: session, appearance: model.buddy, buddyHeight: Self.expandedBuddyHeight,
                onEnd: { model.onEndBreak(session) }
            )
            .foregroundStyle(.white)
            .padding(.top, model.notchSize.height + 6)
            .padding(.horizontal, 18)
        } else {
            promptContent
        }
    }

    private var promptContent: some View {
        HStack(alignment: .top, spacing: 14) {
            BuddySpriteView(
                appearance: model.buddy, mood: model.mood, height: Self.expandedBuddyHeight, pose: model.poseOverride)
            VStack(alignment: .leading, spacing: 5) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.buddy.name)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                    Text(model.prompt?.title ?? "All good")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                Text(model.prompt?.message ?? "I am here. Sit tall and breathe.")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
                if let prompt = model.prompt {
                    HStack(spacing: 8) {
                        Button(prompt.doneTitle) { model.onDone(prompt) }
                        if prompt.canSnooze {
                            Button("Snooze 5 min") { model.onSnooze(prompt) }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .padding(.top, 4)
                }
                if model.waitingCount > 0 {
                    Text("\(model.waitingCount) more waiting")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.top, model.notchSize.height + 6)
        .padding(.horizontal, 18)
    }
}

/// Flat top (it sits against the top of the screen), round bottom corners.
struct IslandShape: Shape {
    var bottomRadius: CGFloat

    var animatableData: CGFloat {
        get { bottomRadius }
        set { bottomRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let radius = min(bottomRadius, rect.height / 2, rect.width / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}
