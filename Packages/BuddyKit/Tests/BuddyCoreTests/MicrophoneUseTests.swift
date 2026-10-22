import Testing

@testable import BuddyCore

@Suite("MicrophoneUse")
struct MicrophoneUseTests {
    private let ownPID: Int32 = 100

    private func client(
        pid: Int32 = 200,
        bundleID: String? = "us.zoom.xos",
        running: Bool = true,
        devices: Int = 1
    ) -> AudioInputClient {
        AudioInputClient(pid: pid, bundleID: bundleID, isRunningInput: running, inputDeviceCount: devices)
    }

    @Test("An app that records from a mic means a call")
    func callAppRecording() {
        #expect(MicrophoneUse.isInUse([client()], ownPID: ownPID))
    }

    @Test func nothingRecording() {
        #expect(!MicrophoneUse.isInUse([], ownPID: ownPID))
        #expect(!MicrophoneUse.isInUse([client(running: false)], ownPID: ownPID))
    }

    @Test("Axo itself never counts")
    func ownProcessIgnored() {
        #expect(!MicrophoneUse.isInUse([client(pid: ownPID)], ownPID: ownPID))
    }

    @Test("The Siri listener is not a call (seen on Hassan's Mac: input on, no device)")
    func siriListenerIgnored() {
        #expect(!MicrophoneUse.isInUse([client(bundleID: "com.apple.CoreSpeech", devices: 0)], ownPID: ownPID))
        #expect(!MicrophoneUse.isInUse([client(bundleID: "com.apple.CoreSpeech", devices: 1)], ownPID: ownPID))
    }

    @Test("Input with no real input device is not a call")
    func noDeviceIgnored() {
        #expect(!MicrophoneUse.isInUse([client(bundleID: nil, devices: 0)], ownPID: ownPID))
    }

    @Test("Music players only play; they do not record")
    func playbackIsNotACall() {
        #expect(!MicrophoneUse.isInUse([client(bundleID: "com.apple.Music", running: false)], ownPID: ownPID))
    }
}
