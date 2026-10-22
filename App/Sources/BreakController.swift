import BuddyCore
import Foundation
import NotchUI
import Observation

/// Runs one break at a time: in the island (gentle) or on every screen (full screen).
///
///     notice in the island ──(10 or 30 s, or "Start now")──▶ start ──▶ island or full screen
///                                                                 └──▶ end: finished, skipped, exit, interrupted
@MainActor
@Observable
final class BreakController {
    private(set) var session: BreakSession?
    /// The reminder whose full-screen break starts when its notice runs out.
    private(set) var noticeReminderID: Reminder.ID?
    @ObservationIgnored var onEnded: (BreakSession, BreakOutcome) -> Void = { _, _ in }

    @ObservationIgnored private let island: IslandModel
    @ObservationIgnored private let screens = BreakScreens()
    @ObservationIgnored private var endTask: Task<Void, Never>?
    @ObservationIgnored private var noticeTask: Task<Void, Never>?

    init(island: IslandModel) {
        self.island = island
        island.onEndBreak = { [weak self] _ in self?.end(.skipped) }
        screens.onSkip = { [weak self] in self?.end(.skipped) }
        screens.onEmergencyExit = { [weak self] in self?.end(.emergencyExit) }
    }

    var isActive: Bool { session != nil }
    var isFullScreen: Bool { session?.isFullScreen ?? false }
    /// True while a break runs or a notice counts down. A second break then waits as a normal prompt.
    var isBusy: Bool { session != nil || noticeReminderID != nil }

    /// Starts the break now. Nil when a break already runs or the reminder has no break time.
    /// A notice that counts down for another reminder stops. The caller takes it out of the island.
    func start(_ reminder: Reminder, style: BreakStrictness, appearance: BuddyAppearance) -> BreakSession? {
        cancelNotice()
        guard session == nil, let session = BreakSession(reminder: reminder, style: style, startedAt: Date()) else {
            return nil
        }
        self.session = session
        if session.isFullScreen {
            screens.show(session, appearance: appearance)
        } else {
            island.startBreak(session)
        }
        endTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(session.duration))
            } catch {
                return  // Ended early.
            }
            // The sleep counts while the Mac sleeps: a Mac that slept through the break did not finish it.
            self?.end(session.outcomeWhenTimeRunsOut(at: Date()))
        }
        return session
    }

    /// Runs `start` after the notice, unless the user answers the notice first.
    func startAfterNotice(for id: Reminder.ID, seconds: TimeInterval, _ start: @escaping @MainActor () -> Void) {
        noticeTask?.cancel()
        noticeReminderID = id
        noticeTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(seconds))
            } catch {
                return  // Answered (Start now or Snooze) before the time ran out.
            }
            self?.noticeReminderID = nil
            start()
        }
    }

    func cancelNotice() {
        noticeTask?.cancel()
        noticeTask = nil
        noticeReminderID = nil
    }

    func end(_ outcome: BreakOutcome) {
        guard let session else { return }
        self.session = nil
        endTask?.cancel()
        endTask = nil
        screens.hide()
        island.endBreak()
        onEnded(session, outcome)
    }
}
