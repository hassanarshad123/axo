import Foundation
import Testing

@testable import BuddyCore

@Suite("BuddyIdleAnimation")
struct BuddyIdleAnimationTests {
    private let idle = BuddyIdleAnimation(bobStep: 0.8, blinkEvery: 4, blinkLength: 0.15)

    @Test("The bob moves 1 pt up and back in whole steps")
    func bobInTwoSteps() {
        #expect(idle.frame(at: 0.1, mood: .calm, canBlink: false).bobOffset == 0)
        #expect(idle.frame(at: 0.9, mood: .calm, canBlink: false).bobOffset == 1)
        #expect(idle.frame(at: 1.7, mood: .calm, canBlink: false).bobOffset == 0)
        let times = stride(from: 0.0, to: 20, by: 0.05)
        let offsets = Set(times.map { idle.frame(at: $0, mood: .happy, canBlink: false).bobOffset })
        #expect(offsets == [0, 1])
    }

    @Test("Blink happens briefly every few seconds, only while calm, and only with blink art")
    func blinkRules() {
        #expect(idle.frame(at: 4.05, mood: .calm, canBlink: true).isBlinking)
        #expect(idle.frame(at: 8.1, mood: .calm, canBlink: true).isBlinking)
        // The blink art is the calm pose: in another mood it would swap the whole pose for a moment.
        #expect(!idle.frame(at: 8.1, mood: .happy, canBlink: true).isBlinking)
        #expect(!idle.frame(at: 4.05, mood: .celebrating, canBlink: true).isBlinking)
        #expect(!idle.frame(at: 4.3, mood: .calm, canBlink: true).isBlinking)
        #expect(!idle.frame(at: 4.05, mood: .calm, canBlink: false).isBlinking)
        #expect(!idle.frame(at: 4.05, mood: .worried, canBlink: true).isBlinking)
        #expect(!idle.frame(at: 4.05, mood: .sleeping, canBlink: true).isBlinking)
    }

    @Test("A sleeping buddy lies still")
    func sleepingIsStill() {
        #expect(idle.frame(at: 0.9, mood: .sleeping, canBlink: true).bobOffset == 0)
    }

    @Test("The next change is the next bob step, or a blink edge when blinking is possible")
    func nextChange() {
        #expect(abs(idle.nextChange(after: 0.1, canBlink: false) - 0.8) < 1e-9)
        #expect(abs(idle.nextChange(after: 3.5, canBlink: true) - 4.0) < 1e-9)
        #expect(abs(idle.nextChange(after: 4.0, canBlink: true) - 4.0 - 0.15) < 1e-9)
        #expect(abs(idle.nextChange(after: 4.0, canBlink: false) - 4.0) > 0.1)
    }

    @Test("Change times always move forward")
    func changesMoveForward() {
        var time = 1_000_000.123
        for _ in 0..<200 {
            let next = idle.nextChange(after: time, canBlink: true)
            #expect(next > time)
            #expect(next - time <= 0.8 + 1e-9)
            time = next
        }
    }
}
