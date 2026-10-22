import BuddyCore
import Testing

@Suite("SensorStatus")
struct SensorStatusTests {
    @Test("A sensor that did not run keeps its last message")
    func notUsedKeepsTheMessage() {
        #expect(SensorStatus.notUsed.message(after: "No camera found") == "No camera found")
        #expect(SensorStatus.notUsed.message(after: nil) == nil)
    }

    @Test("A sensor that worked clears its message")
    func workedClears() {
        #expect(SensorStatus.worked.message(after: "No camera found") == nil)
    }

    @Test("A failure replaces the message")
    func failureReplaces() {
        #expect(SensorStatus.failed("Access is off").message(after: nil) == "Access is off")
        #expect(SensorStatus.failed("Access is off").message(after: "Old") == "Access is off")
    }

    @Test("AirPods working does not hide a camera problem")
    func sensorsStayApart() {
        let cameraMessage = SensorStatus.failed("No camera found").message(after: nil)
        let headphonesMessage = SensorStatus.worked.message(after: nil)
        #expect(SensorStatus.notUsed.message(after: cameraMessage) == "No camera found")
        #expect(headphonesMessage == nil)
    }
}
