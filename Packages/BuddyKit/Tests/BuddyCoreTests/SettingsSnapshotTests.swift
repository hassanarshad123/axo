import Foundation
import Testing

@testable import BuddyCore

@Suite("SettingsSnapshot")
struct SettingsSnapshotTests {
    private func decode(_ json: String) throws -> SettingsSnapshot {
        try JSONDecoder().decode(SettingsSnapshot.self, from: Data(json.utf8))
    }

    private func reminderJSON(interval: Double, breakDuration: Double = 0, kind: String = "standUp") -> String {
        """
        {"id":"\(UUID().uuidString)","kind":"\(kind)","title":"Stand up","message":"Move",\
        "interval":\(interval),"breakDuration":\(breakDuration),"timing":"activeUse","isEnabled":true}
        """
    }

    @Test func roundTrip() throws {
        let baseline = PostureBaseline(headHeight: 1, shoulderWidth: 0.4, shoulderTilt: 0, headPitch: nil)
        let snapshot = SettingsSnapshot(cameraEnabled: false, baseline: baseline, calibratedBaseline: baseline)
        let data = try JSONEncoder().encode(snapshot)
        #expect(try JSONDecoder().decode(SettingsSnapshot.self, from: data) == snapshot)
    }

    @Test("Missing fields get their defaults")
    func emptyGivesDefaults() throws {
        #expect(try decode("{}") == SettingsSnapshot())
    }

    @Test("Unlock codes are saved as typed codes; a text that is not a code is dropped")
    func unlockCodes() throws {
        #expect(SettingsSnapshot().unlockCodes.isEmpty)
        let snapshot = try decode(#"{"unlockCodes":["7kq3-xw9p-2m4t-hb6r","not a code","7KQ3XW9P2M4THB6R"]}"#)
        #expect(snapshot.unlockCodes == [UnlockCode("7KQ3XW9P2M4THB6R")!])
        let data = try JSONEncoder().encode(snapshot)
        #expect(try JSONDecoder().decode(SettingsSnapshot.self, from: data) == snapshot)
    }

    @Test("Settings saved by an older version keep their values")
    func olderVersionKeepsValues() throws {
        let snapshot = try decode(
            """
            {"cameraEnabled":false,"soundEnabled":false,"futureSetting":42,
             "baseline":{"headHeight":1.0,"shoulderWidth":0.4}}
            """)
        #expect(!snapshot.cameraEnabled)
        #expect(!snapshot.soundEnabled)
        #expect(snapshot.headphonesEnabled)
        #expect(snapshot.baseline?.headHeight == 1.0)
        #expect(snapshot.calibratedBaseline == snapshot.baseline)  // old data: the baseline is the anchor
    }

    @Test("A broken field resets only that field")
    func brokenFieldIsLocal() throws {
        let snapshot = try decode(#"{"cameraEnabled":"yes","soundEnabled":false,"strictness":"nope"}"#)
        #expect(snapshot.cameraEnabled)
        #expect(!snapshot.soundEnabled)
        #expect(snapshot.strictness == .gentle)
    }

    @Test("Reminders with a zero or negative interval are dropped, not crashed on")
    func badRemindersAreDropped() throws {
        let json = """
            {"reminders":[\(reminderJSON(interval: 0)),\(reminderJSON(interval: -5)),\
            \(reminderJSON(interval: 600)),\(reminderJSON(interval: 60, kind: "meditate"))]}
            """
        let snapshot = try decode(json)
        #expect(snapshot.reminders.map(\.interval) == [600])
    }

    @Test("If every saved reminder is broken, the defaults come back")
    func allBrokenGivesDefaults() throws {
        let snapshot = try decode(#"{"reminders":[\#(reminderJSON(interval: 0))]}"#)
        #expect(snapshot.reminders == Reminder.defaults)
    }

    @Test("A negative break length is fixed to zero")
    func negativeBreakIsFixed() throws {
        let snapshot = try decode(#"{"reminders":[\#(reminderJSON(interval: 60, breakDuration: -3))]}"#)
        #expect(snapshot.reminders.first?.breakDuration == 0)
    }

    @Test("Buddy settings default to Axo, original color, outline menu bar icon")
    func buddyDefaults() throws {
        let snapshot = try decode(#"{"cameraEnabled":false}"#)
        #expect(snapshot.buddyID == "25-axo-axolotl")
        #expect(snapshot.buddyNames.isEmpty)
        #expect(snapshot.buddyColor == .original)
        #expect(snapshot.menuBarIcon == .outline)
    }

    @Test("The voice coach is on at 70% volume, and a saved volume stays between 0 and 1")
    func voiceSettings() throws {
        let old = try decode(#"{"soundEnabled":false}"#)
        #expect(old.voiceEnabled)
        #expect(old.voiceVolume == 0.7)
        #expect(!old.soundEnabled)
        #expect(try decode(#"{"voiceEnabled":false,"voiceVolume":0.25}"#).voiceVolume == 0.25)
        #expect(try decode(#"{"voiceVolume":3}"#).voiceVolume == 1)
        #expect(try decode(#"{"voiceVolume":-1}"#).voiceVolume == 0)
        #expect(try decode(#"{"voiceVolume":"loud"}"#).voiceVolume == 0.7)
        #expect(!(try decode(#"{"voiceEnabled":false}"#).voiceEnabled))
    }

    @Test("Anonymous usage counts are on unless the user turned them off")
    func usageCounts() throws {
        #expect(try decode("{}").usageCountsEnabled)
        #expect(!(try decode(#"{"usageCountsEnabled":false}"#).usageCountsEnabled))
    }

    @Test("Buddy settings round trip, and a broken one resets alone")
    func buddySettings() throws {
        let snapshot = SettingsSnapshot(
            buddyID: "10-neko-cat", buddyNames: ["10-neko-cat": "Kitty", "25-axo-axolotl": "Bubbles"],
            buddyColor: .sky, menuBarIcon: .color)
        let data = try JSONEncoder().encode(snapshot)
        #expect(try JSONDecoder().decode(SettingsSnapshot.self, from: data) == snapshot)

        let broken = try decode(#"{"buddyID":"10-neko-cat","buddyColor":"plaid","menuBarIcon":"color"}"#)
        #expect(broken.buddyID == "10-neko-cat")
        #expect(broken.buddyColor == .original)
        #expect(broken.menuBarIcon == .color)
    }

    @Test("A saved name longer than 16 characters is cut; an empty one means the buddy's own name")
    func buddyNameIsLimited() throws {
        let snapshot = try decode(#"{"buddyNames":{"10-neko-cat":"Mr Pickles the Third","25-axo-axolotl":"  "}}"#)
        #expect(snapshot.buddyNames == ["10-neko-cat": "Mr Pickles the T"])
    }

    @Test("One name saved by an older version goes to the buddy that was picked then")
    func oldSingleNameMoves() throws {
        let old = try decode(#"{"buddyID":"10-neko-cat","buddyName":"Kitty"}"#)
        #expect(old.buddyNames == ["10-neko-cat": "Kitty"])
        let both = try decode(
            #"{"buddyID":"10-neko-cat","buddyName":"Kitty","buddyNames":{"25-axo-axolotl":"Bubbles"}}"#)
        #expect(both.buddyNames == ["25-axo-axolotl": "Bubbles"])
        #expect(try decode(#"{"buddyName":"Bubbles"}"#).buddyNames == ["25-axo-axolotl": "Bubbles"])
    }

    @Test("A reminder decoded on its own rejects a zero interval")
    func reminderRejectsZeroInterval() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Reminder.self, from: Data(reminderJSON(interval: 0).utf8))
        }
    }

    @Test("Posture setup fields default to: onboarding not done, built-in camera, normal sensitivity")
    func postureSetupFields() throws {
        let empty = try decode("{}")
        #expect(!empty.hasFinishedOnboarding)
        #expect(empty.cameraID == nil)
        #expect(empty.sensitivity == .normal)

        let saved = SettingsSnapshot(hasFinishedOnboarding: true, cameraID: "usb-1", sensitivity: .strict)
        let decoded = try JSONDecoder().decode(SettingsSnapshot.self, from: JSONEncoder().encode(saved))
        #expect(decoded == saved)
        #expect(try decode(#"{"sensitivity":"loose"}"#).sensitivity == .normal)
    }
}
