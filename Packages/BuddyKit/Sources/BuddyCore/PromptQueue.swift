import Foundation

/// One message the buddy shows in the island: a reminder or a posture nudge.
public struct BuddyPrompt: Identifiable, Equatable, Sendable {
    /// The same reminder always has the same id, so it is queued only once.
    public let id: String
    public let title: String
    public let message: String
    public let reminderID: Reminder.ID?
    /// The label of the main button.
    public let doneTitle: String
    public let canSnooze: Bool
    /// The art the buddy shows with the prompt. Nil = the art for its mood.
    public let pose: String?

    public init(
        id: String? = nil,
        title: String,
        message: String,
        reminderID: Reminder.ID? = nil,
        doneTitle: String = "Done",
        canSnooze: Bool = true,
        pose: String? = nil
    ) {
        self.id = id ?? reminderID?.uuidString ?? title
        self.title = title
        self.message = message
        self.reminderID = reminderID
        self.doneTitle = doneTitle
        self.canSnooze = canSnooze
        self.pose = pose
    }

    public static func reminder(_ reminder: Reminder) -> BuddyPrompt {
        BuddyPrompt(
            title: reminder.title, message: reminder.message, reminderID: reminder.id, pose: pose(for: reminder.kind))
    }

    /// The warning before a full-screen break. "Start now" starts it at once.
    /// It has its own id, so a waiting prompt for the same reminder never hides it.
    public static func breakNotice(_ reminder: Reminder, in seconds: TimeInterval, canSnooze: Bool) -> BuddyPrompt {
        let notice = "A full-screen break starts in \(Int(seconds)) seconds."
        let message = reminder.message.isEmpty ? notice : "\(reminder.message) \(notice)"
        return BuddyPrompt(
            id: noticeID(for: reminder.id), title: reminder.title, message: message, reminderID: reminder.id,
            doneTitle: "Start now", canSnooze: canSnooze, pose: pose(for: reminder.kind))
    }

    /// The id of the break notice for this reminder.
    public static func noticeID(for reminderID: Reminder.ID) -> String {
        "notice-\(reminderID.uuidString)"
    }

    /// The nudge after a few bad posture checks in a row. Always the same id, so it is queued only once.
    public static let postureNudge = BuddyPrompt(
        id: "posture", title: "Sit tall", message: "Lift your head and let your shoulders drop. Slow breath in.")

    /// The buddy reached a new form. One id per form, so it is queued only once.
    public static func grewUp(name: String, form: Int) -> BuddyPrompt {
        BuddyPrompt(
            id: "grew-up-\(form)", title: "\(name) grew up!",
            message: "Good days help \(name) grow. Open Progress to see every form.",
            doneTitle: "Yay", canSnooze: false, pose: "celebrate")
    }

    static func pose(for kind: Reminder.Kind) -> String? {
        switch kind {
        case .standUp: "walk"
        case .eyeRest: "eyes"
        case .drinkWater: "water"
        case .stretch: "stretching"
        case .custom: nil
        }
    }
}

/// Prompts that wait for the user. A value type: each change returns a new queue.
///
///     [current] [next] [next] ... [auto-closed] [auto-closed]
///         ▲ shown in the island; Done or Snooze removes it
///
/// Rules:
/// - A new prompt never replaces one the user has not answered. It waits behind it.
/// - A prompt that closed by itself (`autoClosingCurrent`) moves to the back and keeps waiting.
///   It opens the island by itself only once; after that it waits behind a small dot.
/// - New prompts go ahead of prompts that already closed by themselves.
public struct PromptQueue: Sendable, Equatable {
    public struct Entry: Sendable, Equatable {
        public let prompt: BuddyPrompt
        /// True after the prompt was shown once and closed by itself.
        public let autoClosed: Bool

        public init(prompt: BuddyPrompt, autoClosed: Bool) {
            self.prompt = prompt
            self.autoClosed = autoClosed
        }
    }

    public let entries: [Entry]

    public init(entries: [Entry] = []) {
        self.entries = entries
    }

    /// The prompt the island shows when it is open.
    public var current: BuddyPrompt? { entries.first?.prompt }
    public var count: Int { entries.count }
    public var isEmpty: Bool { entries.isEmpty }
    /// True when the island should open by itself to show `current`.
    public var shouldOpen: Bool { entries.first.map { !$0.autoClosed } ?? false }

    /// Adds a prompt. A prompt that is already in the queue is not added again.
    /// - Parameter currentIsOnScreen: true while the user can see `current` (it is then never pushed back).
    public func adding(_ prompt: BuddyPrompt, currentIsOnScreen: Bool) -> PromptQueue {
        guard !entries.contains(where: { $0.prompt.id == prompt.id }) else { return self }
        let firstAutoClosed = entries.firstIndex(where: \.autoClosed) ?? entries.count
        let position = firstAutoClosed == 0 && currentIsOnScreen && !entries.isEmpty ? 1 : firstAutoClosed
        var newEntries = entries
        newEntries.insert(Entry(prompt: prompt, autoClosed: false), at: position)
        return PromptQueue(entries: newEntries)
    }

    /// The user answered the current prompt (Done or Snooze).
    public func answeringCurrent() -> PromptQueue {
        PromptQueue(entries: Array(entries.dropFirst()))
    }

    /// The current prompt closed by itself. It moves to the back and keeps waiting.
    public func autoClosingCurrent() -> PromptQueue {
        guard let first = entries.first else { return self }
        return PromptQueue(entries: Array(entries.dropFirst()) + [Entry(prompt: first.prompt, autoClosed: true)])
    }

    /// Takes prompts back, for example sitting reminders after the user took a break.
    public func removing(ids: Set<BuddyPrompt.ID>) -> PromptQueue {
        PromptQueue(entries: entries.filter { !ids.contains($0.prompt.id) })
    }
}
