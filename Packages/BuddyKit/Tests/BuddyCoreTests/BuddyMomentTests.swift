import Testing

@testable import BuddyCore

@Suite("BuddyMoment")
struct BuddyMomentTests {
    /// The moment art of the duo, two buddies together (DECISIONS #39).
    private let duo: Set<String> = [
        "happy", "worried", "sleeping", "stretching", "neck", "water", "eyes", "celebrate",
        "wave", "walk", "laptop", "chai", "thumbs-up", "fist-bump", "breathe", "trophy",
    ]
    private let core: Set<String> = [
        "happy", "worried", "sleeping", "stretching", "neck", "water", "eyes", "celebrate",
    ]

    @Test("Each moment has its own pose, and the duo has art for every one")
    func posesExistForTheDuo() {
        let poses = BuddyMoment.allCases.map(\.pose)
        #expect(Set(poses).count == poses.count)
        for moment in BuddyMoment.allCases {
            #expect(BuddyAssets.resolve(moment.pose, available: duo) == moment.pose, "\(moment)")
        }
    }

    @Test("A buddy without moment art shows a close core pose")
    func fallsBackToCorePoses() {
        #expect(BuddyAssets.resolve(BuddyMoment.chaiBreak.pose, available: core) == "water")
        #expect(BuddyAssets.resolve(BuddyMoment.breakDone.pose, available: core) == "celebrate")
        #expect(BuddyAssets.resolve(BuddyMoment.weeklyGoal.pose, available: core) == "celebrate")
        #expect(BuddyAssets.resolve(BuddyMoment.hello.pose, available: core) == "happy")
        #expect(BuddyAssets.resolve(BuddyMoment.walkBreak.pose, available: core) == "stretching")
        #expect(BuddyAssets.resolve(BuddyMoment.breathe.pose, available: core) == "happy")
        #expect(BuddyAssets.resolve(BuddyMoment.celebrate.pose, available: core) == "celebrate")
    }

    @Test("A moment shows for a few seconds")
    func duration() {
        #expect(BuddyMoment.showFor > 2)
        #expect(BuddyMoment.showFor <= 6)
    }
}
