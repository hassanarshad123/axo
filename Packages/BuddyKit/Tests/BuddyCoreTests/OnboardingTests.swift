import Testing

@testable import BuddyCore

@Suite("Onboarding steps and sensitivity")
struct OnboardingTests {
    @Test("The steps go in order, and the ends stay put")
    func order() {
        #expect(OnboardingStep.allCases.first == .welcome)
        #expect(OnboardingStep.allCases.last == .done)
        #expect(OnboardingStep.welcome.previous == nil)
        #expect(OnboardingStep.done.next == nil)
        #expect(OnboardingStep.welcome.next == .buddy)
        #expect(OnboardingStep.calibrate.previous == .airPods)
        #expect(OnboardingStep.allCases.allSatisfy { !$0.title.isEmpty })
    }

    @Test("Relaxed gives more room than normal, strict less")
    func sensitivityScale() {
        #expect(PostureSensitivity.relaxed.limitScale > PostureSensitivity.normal.limitScale)
        #expect(PostureSensitivity.strict.limitScale < PostureSensitivity.normal.limitScale)
        #expect(PostureSensitivity.normal.limitScale == 1)
    }
}
