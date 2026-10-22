import BuddyCore
import CoreGraphics
import Foundation

/// Reads raw signals from macOS. The rules that turn them into an `ActivityState` live in BuddyCore.
public enum ActivitySensors {
    /// Seconds since the last keyboard, mouse or trackpad input anywhere on the Mac.
    public static func secondsSinceLastInput() -> TimeInterval {
        guard let anyInput = CGEventType(rawValue: UInt32.max) else { return 0 }
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }

    /// True if another app records from a microphone, for example Zoom, Meet, Teams or FaceTime.
    /// This only asks "is the mic running". It does not listen and needs no mic permission.
    ///
    /// - macOS 14.2 and later: asks macOS which apps run audio input, so any microphone counts
    ///   (not only the default one). Our own app and "Hey Siri" are skipped (`MicrophoneUse`).
    /// - Older macOS, or if that fails: asks every device that has a microphone "are you running?".
    public static func isMicrophoneInUse() -> Bool {
        if #available(macOS 14.2, *), let clients = AudioHardware.inputClients() {
            return MicrophoneUse.isInUse(clients, ownPID: ProcessInfo.processInfo.processIdentifier)
        }
        return AudioHardware.anyInputDeviceIsRunning()
    }
}
