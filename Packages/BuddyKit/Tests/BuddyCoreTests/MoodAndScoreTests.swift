import Foundation
import Testing

@testable import BuddyCore

@Suite("ActivityState")
struct ActivityStateTests {
    @Test func pauseWins() {
        #expect(ActivityState.resolve(idleSeconds: 0, microphoneInUse: true, isPausedByUser: true) == .paused)
    }

    @Test func callBeatsIdle() {
        #expect(ActivityState.resolve(idleSeconds: 999, microphoneInUse: true, isPausedByUser: false) == .inMeeting)
    }

    @Test func idleMeansAway() {
        #expect(ActivityState.resolve(idleSeconds: 120, microphoneInUse: false, isPausedByUser: false) == .away)
        #expect(ActivityState.resolve(idleSeconds: 119, microphoneInUse: false, isPausedByUser: false) == .active)
    }
}

@Suite("BuddyMood")
struct BuddyMoodTests {
    @Test func levelUpBeatsEverything() {
        #expect(
            BuddyMood.resolve(activity: .away, posture: .unknown, isOnBreak: true, justLeveledUp: true) == .celebrating)
    }

    @Test func breakBeatsPosture() {
        #expect(
            BuddyMood.resolve(activity: .active, posture: .slouching([.headDropped]), isOnBreak: true) == .stretching)
    }

    @Test func postureDrivesTheFace() {
        #expect(BuddyMood.resolve(activity: .active, posture: .good, isOnBreak: false) == .happy)
        #expect(BuddyMood.resolve(activity: .active, posture: .slouching([.leaningIn]), isOnBreak: false) == .worried)
        #expect(BuddyMood.resolve(activity: .inMeeting, posture: .unknown, isOnBreak: false) == .calm)
    }

    @Test func awaySleeps() {
        #expect(BuddyMood.resolve(activity: .away, posture: .good, isOnBreak: false) == .sleeping)
        #expect(BuddyMood.resolve(activity: .paused, posture: .good, isOnBreak: false) == .sleeping)
    }
}

@Suite("PostureScore")
struct PostureScoreTests {
    @Test func noDataIsNil() {
        #expect(PostureScore.daily([]) == nil)
        #expect(PostureScore.daily([.unknown, .unknown]) == nil)
    }

    @Test func percentOfKnownChecks() {
        let checks: [PostureAssessment] = [.good, .good, .good, .slouching([.headDropped]), .unknown]
        #expect(PostureScore.daily(checks) == 75)
    }

    @Test func streakCountsBackFromToday() {
        #expect(PostureScore.streak([90, 40, 80, 75, 71]) == 3)
        #expect(PostureScore.streak([90, 80, nil]) == 0)
        #expect(PostureScore.streak([]) == 0)
    }
}

@Suite("PostureAssessment.majority")
struct PostureMajorityTests {
    @Test func unknownOnly() {
        #expect(PostureAssessment.majority([.unknown]) == .unknown)
    }

    @Test func goodWinsWhenMostAreGood() {
        #expect(PostureAssessment.majority([.good, .good, .slouching([.headDropped])]) == .good)
    }

    @Test func halfSlouchingIsSlouching() {
        let result = PostureAssessment.majority([.good, .slouching([.leaningIn]), .slouching([.headDropped]), .good])
        #expect(result == .slouching([.headDropped, .leaningIn]))
    }
}

@Suite("PostureAssessment.combined")
struct PostureCombinedVoteTests {
    @Test("The camera decides when it saw the user")
    func cameraFirst() {
        #expect(PostureAssessment.combined(camera: .good, headphones: .slouching([.headTiltedDown])) == .good)
        #expect(
            PostureAssessment.combined(camera: .slouching([.headDropped]), headphones: .good)
                == .slouching([.headDropped]))
    }

    @Test("AirPods decide only when the camera has no answer")
    func airPodsAsBackup() {
        #expect(
            PostureAssessment.combined(camera: .unknown, headphones: .slouching([.headTiltedDown]))
                == .slouching([.headTiltedDown]))
        #expect(PostureAssessment.combined(camera: .unknown, headphones: .unknown) == .unknown)
    }
}
