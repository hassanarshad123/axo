import BuddyCore
import Foundation
import Observation

/// Everything the island shows. The app writes to it; the views read it.
///
///     show(prompt) ──▶ expanded ──Done / Snooze──▶ next prompt, or compact
///                         │
///                         └─ no answer for 30 s ──▶ compact + dot (the prompt keeps waiting;
///                                                   hover shows it again)
///
///     startBreak ──▶ expanded with the break (never closes by itself; new prompts wait) ──endBreak──▶ next prompt
///     showMoment ──▶ the moment's pose for a few seconds, then the mood again
@MainActor
@Observable
public final class IslandModel {
    public enum Presentation: Equatable {
        /// Small: face on the left of the notch, next timer on the right.
        case compact
        /// Bigger: a message, for example a reminder or a posture nudge.
        case expanded
    }

    public typealias Prompt = BuddyPrompt

    public var mood: BuddyMood = .calm
    /// Which buddy to draw, its name and its color.
    public var buddy: BuddyAppearance = .axo
    public private(set) var presentation: Presentation = .compact
    /// Prompts that wait for an answer. The first one is the one on screen.
    public private(set) var queue = PromptQueue()
    /// Short text on the right side of the notch, for example "12m".
    public var trailingText: String = ""
    public var notchSize: CGSize = NotchGeometry.fakeIslandSize
    public private(set) var isHovering = false

    /// The gentle break on show in the island. Full-screen breaks are not shown here.
    public private(set) var activeBreak: BreakSession?
    /// The pose of a moment that plays now (`BuddyMoment`), for a few seconds.
    public private(set) var momentPose: String?

    public var onDone: (Prompt) -> Void = { _ in }
    public var onSnooze: (Prompt) -> Void = { _ in }
    /// The user pressed End on the break in the island.
    public var onEndBreak: (BreakSession) -> Void = { _ in }

    /// An open prompt with no answer closes after this time.
    private let autoCollapseDelay: Duration
    /// The pointer must stay on the island this long before it opens.
    private let hoverDelay: Duration
    private let momentDuration: Duration
    @ObservationIgnored private var collapseTask: Task<Void, Never>?
    @ObservationIgnored private var hoverTask: Task<Void, Never>?
    @ObservationIgnored private var momentTask: Task<Void, Never>?

    public init(
        autoCollapseDelay: Duration = .seconds(30),
        hoverDelay: Duration = .milliseconds(400),
        momentDuration: Duration = .seconds(BuddyMoment.showFor)
    ) {
        self.autoCollapseDelay = autoCollapseDelay
        self.hoverDelay = hoverDelay
        self.momentDuration = momentDuration
    }

    public var isExpanded: Bool { presentation == .expanded || isHovering }
    /// The prompt the island shows when it is open.
    public var prompt: Prompt? { queue.current }
    /// True while any prompt waits. The compact island shows a small dot.
    public var hasWaitingPrompt: Bool { !queue.isEmpty }
    /// Prompts behind the one on screen.
    public var waitingCount: Int { max(0, queue.count - 1) }

    /// The pose to draw instead of the mood's pose: a moment first, then the open prompt's pose.
    /// Nil = the mood's pose (and the idle blink).
    public var poseOverride: String? {
        momentPose ?? (presentation == .expanded ? prompt?.pose : nil)
    }

    /// The pose the island draws now (a break draws its own step pose).
    public var pose: String { poseOverride ?? BuddyAssets.pose(for: mood) }

    /// Queues a prompt. It opens the island at once, unless another prompt is open: then it waits its turn.
    public func show(_ prompt: Prompt) {
        queue = queue.adding(prompt, currentIsOnScreen: presentation == .expanded)
        if activeBreak == nil, presentation == .compact, queue.shouldOpen {
            open()
        }
    }

    /// Shows a gentle break in the island until `endBreak`. Prompts that arrive meanwhile wait.
    public func startBreak(_ session: BreakSession) {
        collapseTask?.cancel()
        collapseTask = nil
        activeBreak = session
        presentation = .expanded
    }

    /// The break is over (finished or ended). The next waiting prompt shows, if any.
    public func endBreak() {
        guard activeBreak != nil else { return }
        activeBreak = nil
        showNextOrClose()
    }

    /// Plays a moment for a few seconds. A new moment replaces the one on show.
    public func showMoment(_ moment: BuddyMoment) {
        momentTask?.cancel()
        momentPose = moment.pose
        momentTask = Task { [weak self, momentDuration] in
            do {
                try await Task.sleep(for: momentDuration)
            } catch {
                return  // Replaced by a newer moment.
            }
            self?.momentPose = nil
        }
    }

    /// The user answered the prompt on screen (Done or Snooze). The next waiting prompt shows, if any.
    public func dismissPrompt() {
        queue = queue.answeringCurrent()
        guard activeBreak == nil else { return }
        showNextOrClose()
    }

    /// Takes prompts back, for example sitting reminders after the user took a break.
    public func withdraw(ids: Set<Prompt.ID>) {
        let before = queue.current
        queue = queue.removing(ids: ids)
        guard queue.current != before, activeBreak == nil else { return }
        showNextOrClose()
    }

    /// Called by the view when the pointer enters or leaves the island.
    public func hoverChanged(_ hovering: Bool) {
        hoverTask?.cancel()
        hoverTask = nil
        guard hovering, hoverDelay > .zero else {
            isHovering = hovering
            return
        }
        hoverTask = Task { [weak self, hoverDelay] in
            do {
                try await Task.sleep(for: hoverDelay)
            } catch {
                return  // The pointer left before the delay ended.
            }
            self?.isHovering = true
        }
    }

    private func showNextOrClose() {
        if queue.shouldOpen {
            open()
        } else {
            close()
        }
    }

    private func open() {
        presentation = .expanded
        scheduleCollapse()
    }

    private func close() {
        collapseTask?.cancel()
        collapseTask = nil
        presentation = .compact
    }

    private func scheduleCollapse() {
        collapseTask?.cancel()
        collapseTask = Task { [weak self, autoCollapseDelay] in
            do {
                try await Task.sleep(for: autoCollapseDelay)
            } catch {
                return  // Answered, withdrawn or replaced before the delay ended.
            }
            self?.collapseUnanswered()
        }
    }

    /// No answer in time: the prompt moves to the back of the queue and keeps waiting.
    private func collapseUnanswered() {
        guard presentation == .expanded, !queue.isEmpty, activeBreak == nil else { return }
        guard !isHovering else {
            scheduleCollapse()  // The user is reading it. Try again later.
            return
        }
        queue = queue.autoClosingCurrent()
        showNextOrClose()
    }
}
