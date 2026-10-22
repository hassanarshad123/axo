import BuddyCore
import SwiftUI

/// The buddy art for a mood, with a small idle loop: a 1 pt bob, and a blink when the buddy has blink art.
///
/// The view redraws only when the frame changes (see `BuddyIdleAnimation.nextChange`), not 60 times a second.
/// With Reduce Motion on, the buddy stands still.
public struct BuddySpriteView: View {
    public let appearance: BuddyAppearance
    public let mood: BuddyMood
    public let height: CGFloat
    /// False draws one still frame, for example in a grid of many buddies.
    public let animates: Bool
    /// A pose to draw instead of the mood's pose, for example a stretch step or a moment. No blink then.
    public let pose: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let idle = BuddyIdleAnimation()
    /// The view is always this many times as wide as it is tall: the widest art (Goo) is 1.25.
    /// Poses come from different sheets with different shapes, so without a fixed width
    /// the text next to the buddy moves each time the pose changes.
    static let widthRatio: CGFloat = 1.25

    public init(
        appearance: BuddyAppearance, mood: BuddyMood, height: CGFloat, animates: Bool = true, pose: String? = nil
    ) {
        self.appearance = appearance
        self.mood = mood
        self.height = height
        self.animates = animates
        self.pose = pose
    }

    public var body: some View {
        // The blink art of the form on show. Another form's blink would change the buddy for one frame.
        let canBlink =
            pose == nil
            && BuddySprites.shared.hasAsset(
                BuddyAssets.asset("blink", form: appearance.form), buddyID: appearance.buddyID)
        Group {
            if animates && !reduceMotion {
                TimelineView(IdleSchedule(animation: Self.idle, canBlink: canBlink)) { context in
                    sprite(
                        Self.idle.frame(
                            at: context.date.timeIntervalSinceReferenceDate, mood: mood, canBlink: canBlink))
                }
            } else {
                sprite(.still)
            }
        }
        .frame(width: height * Self.widthRatio, height: height)
        .accessibilityElement()
        .accessibilityLabel(Text(pose.map { "\(appearance.name): \($0)" } ?? "\(appearance.name) is \(mood.rawValue)"))
    }

    private func sprite(_ frame: BuddyIdleAnimation.Frame) -> some View {
        let shown = frame.isBlinking ? "blink" : pose ?? BuddyAssets.pose(for: mood)
        let art = BuddySprites.shared.image(
            buddyID: appearance.buddyID, color: appearance.color, pose: shown, form: appearance.form)
        return Group {
            if let art {
                Image(nsImage: art)
                    .resizable()
                    // The art has soft edges (not a hard pixel grid), so smooth scaling looks best.
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "face.smiling")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(.white)
                    .padding(height * 0.15)
            }
        }
        .offset(y: -frame.bobOffset)
    }
}

/// Redraw times for `TimelineView`: only the moments when the idle frame changes.
struct IdleSchedule: TimelineSchedule {
    let animation: BuddyIdleAnimation
    let canBlink: Bool

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries {
        Entries(animation: animation, canBlink: canBlink, upcoming: startDate.timeIntervalSinceReferenceDate)
    }

    struct Entries: Sequence, IteratorProtocol {
        let animation: BuddyIdleAnimation
        let canBlink: Bool
        var upcoming: TimeInterval

        mutating func next() -> Date? {
            let date = Date(timeIntervalSinceReferenceDate: upcoming)
            upcoming = animation.nextChange(after: upcoming, canBlink: canBlink)
            return date
        }
    }
}
