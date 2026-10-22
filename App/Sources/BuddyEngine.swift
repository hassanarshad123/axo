import ActivityMonitor
import AppKit
import BuddyCore
import Foundation
import NotchUI
import Observation

/// The heart of the app. It runs two loops:
///
///     every 5 s   activity (away? locked? in a call?) ─▶ reminder schedule ─▶ island queue + banner
///     every 60 s  camera 3 s + AirPods 3 s ─▶ posture check (camera first) ─▶ buddy mood
///
/// The reminder loop measures the real time since the last tick. A gap over 30 s means the Mac
/// slept, and the whole gap counts as away (`TickTiming`). Breaks run in `BreakController`.
/// Other parts (history, voice, usage counts) listen to `EngineEvent`s, so this file stays small.
@MainActor
@Observable
final class BuddyEngine {
    private(set) var schedule: ReminderSchedule
    private(set) var activity: ActivityState = .active
    var isPausedByUser = false {
        didSet { if isPausedByUser, let id = breaks.noticeReminderID { postponeBreakNotice(for: id) } }
    }

    let island: IslandModel
    let settings: SettingsStore
    let breaks: BreakController
    let postureMonitor: PostureMonitor
    let progress: ProgressTracker
    let voice: VoiceCoach

    @ObservationIgnored private let usage: UsageCounts
    @ObservationIgnored private let screen = ScreenStateMonitor()
    @ObservationIgnored private lazy var presence = PresenceWatcher { [weak self] in
        await self?.postureMonitor.lookForPerson() ?? nil
    }
    @ObservationIgnored private var loops: [Task<Void, Never>] = []
    @ObservationIgnored private var lastTick: ContinuousClock.Instant?
    @ObservationIgnored private var awaySince: Date?
    /// The buddy at the last `appearanceChanged()`, so a new name or color is not a new pick.
    @ObservationIgnored private var lastBuddyID: String
    @ObservationIgnored private var listeners: [@MainActor (EngineEvent) -> Void] = []

    static let tickInterval: TimeInterval = 5
    static let postureCheckInterval: TimeInterval = 60
    static let snoozeDuration: TimeInterval = 5 * 60

    init(settings: SettingsStore, island: IslandModel) {
        self.settings = settings
        self.island = island
        breaks = BreakController(island: island)
        postureMonitor = PostureMonitor(settings: settings, photos: ProgressPhotos())
        progress = ProgressTracker.openingFile()
        voice = VoiceCoach(settings: settings)
        usage = UsageCounts(settings: settings)
        lastBuddyID = settings.buddyID
        schedule = ReminderSchedule(reminders: settings.reminders)
        island.onDone = { [weak self] prompt in self?.finish(prompt) }
        island.onSnooze = { [weak self] prompt in self?.snooze(prompt) }
        breaks.onEnded = { [weak self] session, outcome in self?.breakEnded(session, outcome) }
        progress.onMilestone = { [weak self] milestone in self?.celebrate(milestone) }
        postureMonitor.onEvent = { [weak self] event in self?.send(event) }
        voice.conditions = { [weak self] in (self?.activity ?? .active, self?.screen.isLockedOrAsleep ?? false) }
        addListener { [progress] event in progress.handle(event) }
        addListener { [voice] event in voice.handle(event) }
        addListener { [usage] event in usage.handle(event) }
    }

    /// Adds a listener for everything the engine does (history, voice, usage counts).
    func addListener(_ listener: @escaping @MainActor (EngineEvent) -> Void) {
        listeners.append(listener)
    }

    private func send(_ event: EngineEvent) {
        listeners.forEach { $0(event) }
    }

    var mood: BuddyMood {
        BuddyMood.resolve(activity: activity, posture: postureMonitor.posture, isOnBreak: breaks.isActive)
    }

    var menuBarSymbol: String {
        switch mood {
        case .happy: "figure.stand"
        case .calm: "face.smiling"
        case .worried: "exclamationmark.circle"
        case .sleeping: isPausedByUser ? "pause.circle" : "moon.zzz"
        case .stretching: "figure.cooldown"
        case .celebrating: "sparkles"
        }
    }

    /// The buddy the user picked, with its name and color. An id that is not in the catalog shows Axo.
    var appearance: BuddyAppearance {
        BuddyAppearance.resolve(
            buddyID: settings.buddyID,
            names: settings.buddyNames,
            color: settings.buddyColor,
            catalog: BuddySprites.shared.catalog,
            form: progress.form
        )
    }

    /// The menu bar icon from the buddy art. Nil means "use `menuBarSymbol`" (no outline art yet).
    var menuBarImage: NSImage? {
        let look = appearance
        return BuddySprites.shared.menuBarImage(buddyID: look.buddyID, color: look.color, style: settings.menuBarIcon)
    }

    func start() {
        guard loops.isEmpty else { return }
        screen.start()
        lastTick = .now
        loops = [
            repeatingTask(every: Self.tickInterval, owner: self) { engine in engine.tick() },
            repeatingTask(every: Self.postureCheckInterval, owner: self) { engine in await engine.checkPosture() },
        ]
        refreshIsland()
        island.showMoment(.hello)
        send(.appStarted)
    }

    func stop() {
        loops.forEach { $0.cancel() }
        loops = []
        screen.stop()
        progress.flush()
    }

    /// Call after the user edits reminders in Settings.
    func remindersChanged() {
        schedule = schedule.replacingReminders(settings.reminders)
        refreshIsland()
    }

    /// "Stretch now" in the menu: the stretch break starts at once, in the user's break style.
    func stretchNow() {
        let saved = settings.reminders.first { $0.kind == .stretch && $0.breakDuration > 0 }
        guard let reminder = saved ?? Reminder.defaults.first(where: { $0.kind == .stretch }) else { return }
        startBreak(reminder)
    }

    /// Call after the user picks another buddy, name or color in Settings.
    func appearanceChanged() {
        if settings.buddyID != lastBuddyID {
            lastBuddyID = settings.buddyID
            send(.buddyPicked(buddyID: settings.buddyID))
        }
        refreshIsland()
    }

    /// "Done" in the setup window. Opening the guide again later is not a new setup.
    func setupFinished() {
        guard !settings.hasFinishedOnboarding else { return }
        settings.hasFinishedOnboarding = true
        send(.setupFinished(buddyID: settings.buddyID))
    }

    // MARK: - Reminders

    private func tick() {
        let now = ContinuousClock.now
        let elapsed = lastTick.map { (now - $0).timeInterval } ?? Self.tickInterval
        lastTick = now

        let previous = activity
        activity = currentActivity()
        noteAway(from: previous)
        endFullScreenBreakIfNeeded()
        let counted = TickTiming.countedState(elapsed: elapsed, current: activity)
        if counted == .active || counted == .inMeeting {
            send(.atMac(seconds: elapsed))
        }
        let result = schedule.advanced(by: elapsed, state: counted)
        schedule = result.schedule
        if schedule.tookBreak {
            withdrawSittingPrompts()
        }
        deliver(result.due)
        postureMonitor.rollOver(to: Date())
        refreshIsland()
    }

    private func currentActivity() -> ActivityState {
        let isLockedOrAsleep = screen.isLockedOrAsleep
        let idleSeconds = ActivitySensors.secondsSinceLastInput()
        // The mic cannot change the answer while paused or locked, so do not ask CoreAudio then.
        let microphoneInUse = !isPausedByUser && !isLockedOrAsleep && ActivitySensors.isMicrophoneInUse()
        let canLook =
            postureMonitor.canUseCamera && !isPausedByUser && !isLockedOrAsleep && !microphoneInUse
            && !breaks.isActive
        presence.update(idleSeconds: idleSeconds, cameraAllowed: canLook)
        return ActivityState.resolve(
            idleSeconds: idleSeconds,
            microphoneInUse: microphoneInUse,
            isPausedByUser: isPausedByUser,
            isScreenLockedOrAsleep: isLockedOrAsleep,
            isPersonPresent: presence.isPresent()
        )
    }

    /// Remembers when the user left, and greets them when they come back.
    private func noteAway(from previous: ActivityState) {
        if activity == .away, awaySince == nil {
            awaySince = Date()
        } else if activity == .active, previous == .away, let awaySince {
            self.awaySince = nil
            island.showMoment(.focus)
            send(.cameBack(awayFor: Date().timeIntervalSince(awaySince)))
        }
    }

    /// A full-screen break must not cover a call, and ends when the screen locks or sleeps.
    private func endFullScreenBreakIfNeeded() {
        guard breaks.isFullScreen,
            !BreakSession.mayShowFullScreen(
                isPausedByUser: isPausedByUser, isInCall: activity == .inMeeting,
                isScreenLockedOrAsleep: screen.isLockedOrAsleep)
        else { return }
        breaks.end(.interrupted)
    }

    /// Every due reminder goes into the island queue (one at a time on screen) and gets a banner.
    /// In the full-screen styles, a reminder with a break gets a notice, then its break starts.
    private func deliver(_ due: [Reminder]) {
        for reminder in due {
            send(.reminderDue(reminder))
            switch settings.strictness.delivery(for: reminder) {
            case .fullScreen(let notice, let canSnooze) where !breaks.isBusy:
                island.withdraw(ids: [BuddyPrompt.reminder(reminder).id])  // an older prompt for it
                show(.breakNotice(reminder, in: notice, canSnooze: canSnooze))
                breaks.startAfterNotice(for: reminder.id, seconds: notice) { [weak self] in
                    self?.noticeEnded(for: reminder.id)
                }
            case .prompt, .fullScreen:
                show(.reminder(reminder))
            }
        }
    }

    private func show(_ prompt: BuddyPrompt) {
        island.show(prompt)
        if settings.notificationsEnabled {
            Banners.show(prompt)
        }
    }

    /// The user took a break, so "stand up" and "sit tall" no longer apply.
    private func withdrawSittingPrompts() {
        let sitting = schedule.reminders.filter { $0.timing == .activeUse }.map { BuddyPrompt.reminder($0).id }
        island.withdraw(ids: Set(sitting + [BuddyPrompt.postureNudge.id]))
    }

    /// Done (or Start now): the next reminder of this kind is a full interval from now, and its break starts.
    private func finish(_ prompt: IslandModel.Prompt) {
        island.dismissPrompt()
        guard let id = prompt.reminderID, let reminder = settings.reminders.first(where: { $0.id == id }) else {
            refreshIsland()
            return
        }
        send(.reminderDone(reminder))
        if reminder.breakDuration > 0 {
            startBreak(for: id)
        } else {
            schedule = schedule.resetting(id)
            if reminder.kind == .drinkWater { island.showMoment(.chaiBreak) }
        }
        refreshIsland()
    }

    private func snooze(_ prompt: IslandModel.Prompt) {
        island.dismissPrompt()
        if let id = prompt.reminderID {
            if breaks.noticeReminderID == id { breaks.cancelNotice() }
            schedule = schedule.snoozing(id, by: Self.snoozeDuration)
            if let reminder = settings.reminders.first(where: { $0.id == id }) {
                send(.reminderSnoozed(reminder))
            }
        }
        refreshIsland()
    }

    private func startBreak(for id: Reminder.ID) {
        guard let reminder = settings.reminders.first(where: { $0.id == id }) else { return }
        startBreak(reminder)
    }

    /// The notice ran out. Paused, in a call or locked by now: no full-screen break.
    private func noticeEnded(for id: Reminder.ID) {
        let mayShow = BreakSession.mayShowFullScreen(
            isPausedByUser: isPausedByUser, isInCall: ActivitySensors.isMicrophoneInUse(),
            isScreenLockedOrAsleep: screen.isLockedOrAsleep)
        if mayShow { startBreak(for: id) } else { postponeBreakNotice(for: id) }
    }

    /// Stops the notice and takes it out of the island. The reminder comes back after the
    /// snooze time of counted use (paused time and calls do not count).
    private func postponeBreakNotice(for id: Reminder.ID) {
        breaks.cancelNotice()
        island.withdraw(ids: [BuddyPrompt.noticeID(for: id)])
        schedule = schedule.snoozing(id, by: Self.snoozeDuration)
        refreshIsland()
    }

    private func startBreak(_ reminder: Reminder) {
        // This reminder's prompt or notice, and a notice for another reminder ("Stretch now").
        let notices = [reminder.id, breaks.noticeReminderID].compactMap { $0 }.map(BuddyPrompt.noticeID(for:))
        island.withdraw(ids: Set(notices + [BuddyPrompt.reminder(reminder).id]))
        schedule = schedule.resetting(reminder.id)
        guard let session = breaks.start(reminder, style: settings.strictness, appearance: appearance) else { return }
        send(.breakStarted(session))
        refreshIsland()
    }

    private func breakEnded(_ session: BreakSession, _ outcome: BreakOutcome) {
        if outcome == .finished {
            island.showMoment(.breakDone)
        }
        send(.breakEnded(session, outcome))
        refreshIsland()
    }

    /// Writes only changed values, so the island view does not redraw every 5 seconds for nothing.
    private func refreshIsland() {
        let newMood = mood
        if island.mood != newMood {
            island.mood = newMood
        }
        let text = nextReminderText()
        if island.trailingText != text {
            island.trailingText = text
        }
        let look = appearance
        if island.buddy != look {
            island.buddy = look
        }
    }

    private func nextReminderText() -> String {
        let next = schedule.reminders.compactMap { schedule.remaining(for: $0.id) }.min()
        guard let next else { return "" }
        return "\(Int((next / 60).rounded(.up)))m"
    }

    // MARK: - Posture

    private func checkPosture() async {
        guard !breaks.isActive,
            let result = await postureMonitor.check(activity: activity, isScreenLockedOrAsleep: screen.isLockedOrAsleep)
        else { return }
        send(.postureChecked(result.assessment, sensor: result.sensor))
        if result.assessment.isGood {
            island.withdraw(ids: [BuddyPrompt.postureNudge.id])  // Fixed it already; the nudge is old news.
        }
        if result.fixedAfterNudge {
            island.showMoment(.goodJob)
            send(.postureFixed)
        }
        if result.shouldNudge {
            show(.postureNudge)
            send(.postureNudged(result.assessment))
        }
        refreshIsland()
    }

    // MARK: - Progress

    /// A goal, a streak or a new level: the buddy celebrates. A new form also gets a prompt.
    private func celebrate(_ milestone: ProgressMilestone) {
        switch milestone {
        case .weeklyGoal:
            island.showMoment(.weeklyGoal)
        case .grewUp(let form):
            island.showMoment(.celebrate)
            show(.grewUp(name: appearance.name, form: form))
        case .dailyGoal, .streak, .levelUp:
            island.showMoment(.celebrate)
        }
        send(.milestone(milestone))
        refreshIsland()
    }
}
