import Foundation
import Testing

@testable import BuddyCore

@Suite("Usage report body")
struct UsageReportTests {
    private let context = UsageContext(
        appID: "APP-ID", installID: "install-1", sessionID: "session-1", appVersion: "1.0.0", build: "42",
        systemVersion: "15.1", architecture: "arm64", isTestBuild: false)
    private let date = Date(timeIntervalSince1970: 1_800_000_000)

    private func report(_ signal: UsageSignal = UsageSignal(name: "Reminder.done", parameters: ["kind": "eyeRest"]))
        -> UsageReport
    {
        UsageReport(signal: signal, context: context, at: date)
    }

    @Test("The payload holds the event's own fields and the five app details, nothing else")
    func payloadIsFixed() {
        #expect(
            report().payload == [
                "kind": "eyeRest",
                "TelemetryDeck.AppInfo.version": "1.0.0",
                "TelemetryDeck.AppInfo.buildNumber": "42",
                "TelemetryDeck.Device.platform": "macOS",
                "TelemetryDeck.Device.systemMajorMinorVersion": "15.1",
                "TelemetryDeck.Device.architecture": "arm64",
            ])
    }

    @Test("The random install id leaves only as a SHA-256 hash")
    func installIDIsHashed() {
        let sent = report().clientUser
        #expect(sent != "install-1")
        #expect(sent.count == 64)
        #expect(sent == UsageReport.hashed("install-1"))
        // SHA-256 of "abc", a published test vector.
        #expect(UsageReport.hashed("abc") == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }

    @Test("A test build marks its counts as test counts")
    func testMode() {
        #expect(report().isTestMode == "false")
        let debug = UsageContext(
            appID: "APP-ID", installID: "i", sessionID: "s", appVersion: "1.0.0", build: "1",
            systemVersion: "14.6", architecture: "x86_64", isTestBuild: true)
        #expect(UsageReport(signal: UsageSignal(name: "App.started"), context: debug, at: date).isTestMode == "true")
    }

    @Test("The JSON has exactly the ingest fields, with the date in UTC")
    func json() throws {
        let data = try UsageReport.encode([report()])
        let array = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let body = try #require(array.first)
        #expect(
            Set(body.keys) == ["receivedAt", "appID", "clientUser", "sessionID", "type", "payload", "isTestMode"])
        #expect(body["appID"] as? String == "APP-ID")
        #expect(body["sessionID"] as? String == "session-1")
        #expect(body["type"] as? String == "Reminder.done")
        #expect(body["receivedAt"] as? String == "2027-01-15T08:00:00+0000")
    }

    @Test("Counts go to TelemetryDeck's ingest address only")
    func endpoint() {
        #expect(UsageReport.endpoint.absoluteString == "https://nom.telemetrydeck.com/v2/")
    }
}
