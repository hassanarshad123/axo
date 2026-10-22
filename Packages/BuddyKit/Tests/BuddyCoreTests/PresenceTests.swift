import Foundation
import Testing

@testable import BuddyCore

@Suite("Presence (reading without input)")
struct PresenceTests {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    @Test("No look before 100 s idle, and none with the camera not allowed")
    func waitsForIdle() {
        let presence = Presence.unknown
        #expect(!presence.shouldLook(at: start, idleSeconds: 99, cameraAllowed: true))
        #expect(presence.shouldLook(at: start, idleSeconds: 100, cameraAllowed: true))
        #expect(!presence.shouldLook(at: start, idleSeconds: 300, cameraAllowed: false))
    }

    @Test("A person seen keeps the user present; the next look is a minute later")
    func seenKeepsPresent() {
        let seen = Presence.unknown.recording(seen: true, at: start)
        #expect(seen.isPresent(at: start.addingTimeInterval(30)))
        #expect(!seen.shouldLook(at: start.addingTimeInterval(59), idleSeconds: 159, cameraAllowed: true))
        #expect(seen.shouldLook(at: start.addingTimeInterval(60), idleSeconds: 160, cameraAllowed: true))
    }

    @Test("A look that is too old no longer counts")
    func seenExpires() {
        let seen = Presence.unknown.recording(seen: true, at: start)
        #expect(seen.isPresent(at: start.addingTimeInterval(Presence.seenValidFor - 1)))
        #expect(!seen.isPresent(at: start.addingTimeInterval(Presence.seenValidFor)))
    }

    @Test("Nobody seen: away, and no more looks until the next input")
    func nobodyStopsLooks() {
        let nobody = Presence.unknown.recording(seen: true, at: start).recording(
            seen: false, at: start.addingTimeInterval(60))
        #expect(!nobody.isPresent(at: start.addingTimeInterval(61)))
        #expect(!nobody.shouldLook(at: start.addingTimeInterval(600), idleSeconds: 700, cameraAllowed: true))
    }

    @Test("Input starts fresh")
    func inputResets() {
        let nobody = Presence.unknown.recording(seen: false, at: start)
        #expect(nobody.updated(idleSeconds: 5) == .unknown)
        #expect(nobody.updated(idleSeconds: 150) == nobody)
    }

    @Test("A person seen keeps the user active past the away limit")
    func activityUsesPresence() {
        let idle = ActivityState.defaultAwayAfter + 30
        #expect(ActivityState.resolve(idleSeconds: idle, microphoneInUse: false, isPausedByUser: false) == .away)
        #expect(
            ActivityState.resolve(
                idleSeconds: idle, microphoneInUse: false, isPausedByUser: false, isPersonPresent: true) == .active)
        // A locked screen still wins.
        #expect(
            ActivityState.resolve(
                idleSeconds: idle, microphoneInUse: false, isPausedByUser: false,
                isScreenLockedOrAsleep: true, isPersonPresent: true) == .away)
    }
}
