import Foundation

/// Names of the buddy art files, and what to use when one is missing.
///
///     pose "calm", form 3:  form3-calm ─▶ form3-happy ─▶ calm ─▶ happy
///                            (form 3 art, the fallback pose too)   (form 2 art, last)
///
/// Every buddy has the core poses. More art arrives over time, so every lookup has a fallback.
/// A form's own art comes first, so a form 3 buddy does not jump back to form 2 for one pose.
public enum BuddyAssets {
    /// Form 2 is the plain pose set (no prefix). The buddy's level picks its form (`Progression`).
    public static let plainForm = 2
    public static let forms = 1...5

    /// Poses every buddy has.
    public static let corePoses = ["happy", "worried", "sleeping", "stretching", "neck", "water", "eyes", "celebrate"]

    /// Poses that borrow another pose until their own art exists. A fallback can have its own
    /// fallback: breathe ─▶ calm ─▶ happy. Only the 8 core poses are sure to exist.
    static let fallbacks: [String: String] = [
        "calm": "happy", "blink": "happy",
        // Moments (`BuddyMoment`). The duo (two buddies together) has the art; others borrow a close pose.
        "wave": "happy", "laptop": "happy", "thumbs-up": "happy", "chai": "water",
        "fist-bump": "celebrate", "trophy": "celebrate", "breathe": "calm",
        // Stretch moves (`StretchMove`).
        "neck-left": "neck", "neck-right": "neck", "chin-tuck": "neck", "palming": "eyes",
        "shrug": "stretching", "chest-open": "stretching", "twist-left": "stretching", "twist-right": "stretching",
        "wrist": "stretching", "reach": "stretching", "side-bend": "stretching", "sit-tall": "stretching",
        "march": "stretching", "walk": "stretching",
    ]

    public static func pose(for mood: BuddyMood) -> String {
        switch mood {
        case .happy: "happy"
        case .calm: "calm"
        case .worried: "worried"
        case .sleeping: "sleeping"
        case .stretching: "stretching"
        case .celebrating: "celebrate"
        }
    }

    /// The file name of a pose in one form, with no fallback: "blink" in form 2, "form3-blink" in form 3.
    public static func asset(_ pose: String, form: Int = plainForm) -> String {
        forms.contains(form) && form != plainForm ? "form\(form)-\(pose)" : pose
    }

    /// File names to try for a pose, best first.
    ///
    /// Stretch and moment poses are actions: the right action matters more than the form, so the exact
    /// pose comes first (this form, then the plain set), then the fallbacks. Only form 2 has action art now.
    ///
    ///     "neck-left", form 1:  form1-neck-left ─▶ neck-left ─▶ form1-neck ─▶ neck
    public static func candidates(for pose: String, form: Int = plainForm) -> [String] {
        let poses = chain(from: pose)
        let actions = poses.prefix(while: isAction)
        let rest = poses.dropFirst(actions.count)
        let names = actions.flatMap { [asset($0, form: form), $0] } + rest.map { asset($0, form: form) } + rest
        return names.reduce(into: [String]()) { unique, name in
            if !unique.contains(name) { unique.append(name) }
        }
    }

    /// Calm and blink are idle poses, shown all day: they keep the same form first.
    static func isAction(_ pose: String) -> Bool {
        fallbacks[pose] != nil && pose != "calm" && pose != "blink"
    }

    /// The pose, then its fallback, then that one's fallback. Stops at a pose seen before.
    static func chain(from pose: String) -> [String] {
        var poses = [pose]
        while let next = fallbacks[poses[poses.count - 1]], !poses.contains(next) {
            poses.append(next)
        }
        return poses
    }

    /// The first candidate that exists, or nil.
    public static func resolve(_ pose: String, form: Int = plainForm, available: Set<String>) -> String? {
        candidates(for: pose, form: form).first(where: available.contains)
    }

    /// 36 × 36 px art for the menu bar. When it is missing, the app uses a symbol (outline)
    /// or the happy pose (color).
    public static func menuBarAsset(for style: MenuBarIconStyle) -> String {
        "menubar-\(style.rawValue)"
    }
}
