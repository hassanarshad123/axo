import Foundation

/// One app that talks to the Mac's audio system, as macOS reports it. Plain values only:
/// ActivityMonitor reads them from CoreAudio, this file decides what they mean.
public struct AudioInputClient: Sendable, Equatable {
    public let pid: Int32
    public let bundleID: String?
    /// True if the app runs audio input right now.
    public let isRunningInput: Bool
    /// How many input devices (microphones) the app uses.
    public let inputDeviceCount: Int

    public init(pid: Int32, bundleID: String?, isRunningInput: Bool, inputDeviceCount: Int) {
        self.pid = pid
        self.bundleID = bundleID
        self.isRunningInput = isRunningInput
        self.inputDeviceCount = inputDeviceCount
    }
}

/// Is the user in a call? True when another app records from a real microphone.
/// The app never listens to the microphone; it only reads these flags (docs/PRIVACY.md rule 6).
public enum MicrophoneUse {
    /// System listeners that report input all the time but are not a call.
    /// "Hey Siri" (`corespeechd`) did this on Hassan's Mac, with no input device.
    public static let ignoredBundleIDs: Set<String> = ["com.apple.CoreSpeech"]

    public static func isInUse(_ clients: [AudioInputClient], ownPID: Int32) -> Bool {
        clients.contains { client in
            client.isRunningInput
                && client.pid != ownPID
                && client.inputDeviceCount > 0
                && !ignoredBundleIDs.contains(client.bundleID ?? "")
        }
    }
}
