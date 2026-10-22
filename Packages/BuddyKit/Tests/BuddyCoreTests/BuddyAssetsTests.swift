import Testing

@testable import BuddyCore

@Suite("BuddyAssets")
struct BuddyAssetsTests {
    /// What every buddy has today.
    private let core: Set<String> = [
        "happy", "worried", "sleeping", "stretching", "neck", "water", "eyes", "celebrate",
    ]

    @Test("Each mood has a pose")
    func moodToPose() {
        #expect(BuddyAssets.pose(for: .happy) == "happy")
        #expect(BuddyAssets.pose(for: .calm) == "calm")
        #expect(BuddyAssets.pose(for: .worried) == "worried")
        #expect(BuddyAssets.pose(for: .sleeping) == "sleeping")
        #expect(BuddyAssets.pose(for: .stretching) == "stretching")
        #expect(BuddyAssets.pose(for: .celebrating) == "celebrate")
    }

    @Test("Calm and blink fall back to happy until their art exists")
    func calmAndBlinkFallBack() {
        #expect(BuddyAssets.resolve("calm", available: core) == "happy")
        #expect(BuddyAssets.resolve("blink", available: core) == "happy")
        #expect(BuddyAssets.resolve("calm", available: core.union(["calm"])) == "calm")
        #expect(BuddyAssets.resolve("blink", available: core.union(["blink"])) == "blink")
    }

    @Test("Form 2 is the plain pose set")
    func formTwoIsPlain() {
        #expect(BuddyAssets.plainForm == 2)
        #expect(BuddyAssets.candidates(for: "worried", form: 2) == ["worried"])
        #expect(BuddyAssets.resolve("worried", form: 2, available: core) == "worried")
    }

    @Test("Other forms use formN-<pose>, then fall back to <pose>")
    func otherFormsFallBack() {
        #expect(BuddyAssets.candidates(for: "worried", form: 3) == ["form3-worried", "worried"])
        #expect(BuddyAssets.resolve("worried", form: 3, available: core) == "worried")
        #expect(BuddyAssets.resolve("worried", form: 3, available: core.union(["form3-worried"])) == "form3-worried")
    }

    @Test("A form tries all of its own art before the form 2 art")
    func formArtFirst() {
        #expect(
            BuddyAssets.candidates(for: "calm", form: 5) == ["form5-calm", "form5-happy", "calm", "happy"])
        // Form 5 has no calm pose of its own, but form 2 has one: stay in form 5 (its happy pose).
        let art = core.union(["calm", "form5-happy"])
        #expect(BuddyAssets.resolve("calm", form: 5, available: art) == "form5-happy")
    }

    @Test("The exact file name of a pose in a form, with no fallback")
    func exactAssetName() {
        #expect(BuddyAssets.asset("blink") == "blink")
        #expect(BuddyAssets.asset("blink", form: 2) == "blink")
        #expect(BuddyAssets.asset("blink", form: 4) == "form4-blink")
        #expect(BuddyAssets.asset("blink", form: 9) == "blink")
    }

    @Test("A form out of range is treated as the current form")
    func formOutOfRange() {
        #expect(BuddyAssets.candidates(for: "happy", form: 9) == ["happy"])
        #expect(BuddyAssets.candidates(for: "happy", form: 0) == ["happy"])
    }

    @Test("A pose with no art and no fallback gives nil")
    func missingGivesNil() {
        #expect(BuddyAssets.resolve("juggling", available: core) == nil)
        #expect(BuddyAssets.resolve("happy", available: []) == nil)
    }

    @Test("Stretch poses fall back to the neck or stretching pose")
    func stretchPosesFallBack() {
        for pose in ["neck-left", "neck-right", "chin-tuck"] {
            #expect(BuddyAssets.resolve(pose, available: core) == "neck", "\(pose)")
        }
        let toStretching = ["shrug", "chest-open", "twist-left", "twist-right", "wrist", "reach", "side-bend"]
        for pose in toStretching + ["sit-tall", "march", "walk"] {
            #expect(BuddyAssets.resolve(pose, available: core) == "stretching", "\(pose)")
        }
        #expect(BuddyAssets.resolve("palming", available: core) == "eyes")
        #expect(BuddyAssets.resolve("neck-left", available: core.union(["neck-left"])) == "neck-left")
    }

    @Test("Fallbacks can chain: breathe, then calm, then happy")
    func chainedFallbacks() {
        #expect(BuddyAssets.candidates(for: "breathe") == ["breathe", "calm", "happy"])
        #expect(BuddyAssets.resolve("breathe", available: core) == "happy")
        #expect(BuddyAssets.resolve("breathe", available: core.union(["calm"])) == "calm")
        #expect(
            BuddyAssets.candidates(for: "breathe", form: 3)
                == ["form3-breathe", "breathe", "form3-calm", "form3-happy", "calm", "happy"])
    }

    @Test("A baby buddy shows the exact stretch from the plain set, not its own neck pose")
    func actionsBeforeForms() {
        let baby = core.union(["neck-left", "form1-neck", "form1-happy"])
        #expect(BuddyAssets.resolve("neck-left", form: 1, available: baby) == "neck-left")
        #expect(BuddyAssets.resolve("neck-right", form: 1, available: baby) == "form1-neck")
        #expect(BuddyAssets.resolve("wave", form: 1, available: baby) == "form1-happy")
        // Idle poses still keep the form first.
        #expect(BuddyAssets.resolve("calm", form: 1, available: baby.union(["calm"])) == "form1-happy")
    }

    @Test("Every fallback chain ends")
    func noLoops() {
        for pose in BuddyAssets.fallbacks.keys {
            #expect(
                BuddyAssets.candidates(for: pose, form: 3).count <= 2 * (BuddyAssets.fallbacks.count + 1), "\(pose)")
        }
    }

    @Test func menuBarAssetNames() {
        #expect(BuddyAssets.menuBarAsset(for: .outline) == "menubar-outline")
        #expect(BuddyAssets.menuBarAsset(for: .color) == "menubar-color")
    }
}
