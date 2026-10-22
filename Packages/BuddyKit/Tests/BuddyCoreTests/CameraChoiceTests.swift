import Testing

@testable import BuddyCore

@Suite("CameraChoice")
struct CameraChoiceTests {
    private let builtIn = CameraInfo(id: "built-in", name: "MacBook Pro Camera", kind: .builtIn)
    private let iPhone = CameraInfo(id: "iphone", name: "Hassan's iPhone Camera", kind: .continuity)
    private let usb = CameraInfo(id: "usb", name: "Logitech", kind: .external)

    @Test("The saved camera wins while it is connected")
    func savedWins() {
        #expect(CameraChoice.pick(savedID: "usb", from: [builtIn, iPhone, usb]) == usb)
    }

    @Test("No pick, or a missing one: the built-in camera")
    func fallsBackToBuiltIn() {
        #expect(CameraChoice.pick(savedID: nil, from: [iPhone, builtIn]) == builtIn)
        #expect(CameraChoice.pick(savedID: "gone", from: [iPhone, builtIn]) == builtIn)
    }

    @Test("No built-in camera: a wired one before the iPhone, and nil when there is none")
    func noBuiltIn() {
        #expect(CameraChoice.pick(savedID: nil, from: [iPhone, usb]) == usb)
        #expect(CameraChoice.pick(savedID: nil, from: [iPhone]) == iPhone)
        #expect(CameraChoice.pick(savedID: nil, from: []) == nil)
    }
}
