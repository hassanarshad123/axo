import AVFoundation
import ActivityMonitor
import AppKit
import BuddyCore
import os

/// Plays the recorded voice lines (`App/Resources/Voice/<line>.m4a`) for the engine's events.
///
///     EngineEvent ──▶ VoiceScript.line ──▶ VoiceQueue ──▶ VoiceGate ──▶ AVAudioPlayer
///     breakStarted ──▶ VoiceScript.breakPlan ──▶ a timed task adds each line
///
/// One line plays at a time. The gate is checked again right before each line, so a call
/// that starts while lines wait keeps the coach quiet. With the voice off, a reminder or a
/// nudge plays a short system sound instead (when Sound is on). The coach never listens:
/// it only asks macOS whether some app uses the microphone.
@MainActor
final class VoiceCoach {
    /// What the coach must know about the user right now. The engine sets it.
    var conditions: () -> (activity: ActivityState, isScreenLockedOrAsleep: Bool) = { (.active, false) }

    private let settings: SettingsStore
    private var queue = VoiceQueue.empty
    private var player: AVAudioPlayer?
    /// Waits for the line that plays now to end.
    private var playing: Task<Void, Never>?
    /// Adds the lines of the break that runs now, each at its time.
    private var breakLines: Task<Void, Never>?
    /// Picks between lines with the same meaning (`VoiceScript.line(for:hour:turn:)`).
    private var turn = 0

    /// Silence between two lines, so they do not run together.
    static let gapBetweenLines: TimeInterval = 0.3
    static let fallbackSound = "Glass"
    private static let logger = Logger(subsystem: "com.hassanarshad.axo", category: "Voice")

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func handle(_ event: EngineEvent) {
        switch event {
        case .breakStarted(let session): startBreakLines(session)
        case .breakEnded: stopAll()  // A skipped break must not go on talking.
        default: break
        }
        let hour = Calendar.current.component(.hour, from: Date())
        guard let line = VoiceScript.line(for: event, hour: hour, turn: turn) else { return }
        turn += 1
        say(line, soundIfSilent: Self.hasSound(event))
    }

    /// The Settings "Play" button: one line at the saved volume, even in a call.
    func playSample() {
        stopAll()
        guard let url = Self.url(for: .postureFixed) else { return }
        play(url)
    }

    // MARK: - Queue

    private func say(_ line: VoiceLine, soundIfSilent: Bool) {
        guard settings.voiceEnabled, Self.url(for: line) != nil else {
            if soundIfSilent, settings.soundEnabled { NSSound(named: Self.fallbackSound)?.play() }
            return
        }
        guard canSpeak(checkingMicrophone: false) else { return }
        queue = queue.adding(line, at: Date())
        playNextIfIdle()
    }

    private func playNextIfIdle() {
        guard playing == nil else { return }
        let (line, rest) = queue.next(at: Date())
        queue = rest
        guard let line else { return }
        guard canSpeak(checkingMicrophone: true) else {
            queue = .empty  // Old news by the time the call ends.
            return
        }
        if let url = Self.url(for: line), play(url) { return }
        playNextIfIdle()  // This file could not play. Try the next line.
    }

    @discardableResult
    private func play(_ url: URL) -> Bool {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = Float(settings.voiceVolume)
            guard player.play() else { return false }
            self.player = player
            playing = Task { [weak self] in
                do {
                    try await Task.sleep(for: .seconds(player.duration + Self.gapBetweenLines))
                } catch {
                    return  // Stopped.
                }
                self?.lineEnded()
            }
            return true
        } catch {
            Self.logger.error("Could not play \(url.lastPathComponent, privacy: .public): \(error, privacy: .public)")
            return false
        }
    }

    private func lineEnded() {
        playing = nil
        player = nil
        playNextIfIdle()
    }

    /// Stops the line that plays now, the waiting lines and the break's lines.
    private func stopAll() {
        breakLines?.cancel()
        breakLines = nil
        playing?.cancel()
        playing = nil
        player?.stop()
        player = nil
        queue = .empty
    }

    /// The reminder's own line may still play. The break's first line waits for it in the queue.
    private func startBreakLines(_ session: BreakSession) {
        breakLines?.cancel()
        let cues = VoiceScript.breakPlan(for: session)
        breakLines = Task { [weak self] in
            for cue in cues {
                let wait = session.startedAt.addingTimeInterval(cue.offset).timeIntervalSinceNow
                if wait > 0 {
                    do { try await Task.sleep(for: .seconds(wait)) } catch { return }
                }
                self?.say(cue.line, soundIfSilent: false)
            }
        }
    }

    // MARK: - Rules

    private func canSpeak(checkingMicrophone: Bool) -> Bool {
        let now = conditions()
        return VoiceGate.canSpeak(
            voiceEnabled: settings.voiceEnabled,
            activity: now.activity,
            isScreenLockedOrAsleep: now.isScreenLockedOrAsleep,
            microphoneInUse: checkingMicrophone && ActivitySensors.isMicrophoneInUse()
        )
    }

    /// The events that played a sound before the voice coach existed.
    private static func hasSound(_ event: EngineEvent) -> Bool {
        switch event {
        case .reminderDue, .postureNudged: true
        default: false
        }
    }

    private static func url(for line: VoiceLine) -> URL? {
        let url = Bundle.main.url(forResource: line.rawValue, withExtension: "m4a")
        if url == nil { logger.error("No voice file for \(line.rawValue, privacy: .public)") }
        return url
    }
}
