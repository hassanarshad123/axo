// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BuddyKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BuddyCore", targets: ["BuddyCore"]),
        .library(name: "PostureEngine", targets: ["PostureEngine"]),
        .library(name: "ActivityMonitor", targets: ["ActivityMonitor"]),
        .library(name: "NotchUI", targets: ["NotchUI"]),
        .library(name: "History", targets: ["History"]),
    ],
    targets: [
        // Pure logic: reminders, scheduling, mood, scores. No Apple UI or device frameworks.
        .target(name: "BuddyCore"),

        // Posture from the camera (Vision body pose) and AirPods (head motion).
        .target(name: "PostureEngine", dependencies: ["BuddyCore"]),

        // Is the user away? Is the user in a call?
        .target(name: "ActivityMonitor", dependencies: ["BuddyCore"]),

        // The buddy island that lives in the MacBook notch (or a fake island on other screens).
        // Buddies/ holds catalog.json and <buddy id>/<pose>.png, written by scripts/export-buddy-assets.py.
        // Packs/ holds the locked buddy packs (BuddyPack), written by `make packs`.
        .target(name: "NotchUI", dependencies: ["BuddyCore"], resources: [.copy("Resources/Buddies"), .copy("Resources/Packs")]),

        // Posture checks, reminders and day totals in a SwiftData file on this Mac.
        .target(name: "History", dependencies: ["BuddyCore"]),

        // Makes the codes and the locked buddy packs. Not part of the app.
        .executableTarget(name: "axo-pack", dependencies: ["BuddyCore"]),

        .testTarget(name: "BuddyCoreTests", dependencies: ["BuddyCore"]),
        .testTarget(name: "PostureEngineTests", dependencies: ["PostureEngine"]),
        .testTarget(name: "NotchUITests", dependencies: ["NotchUI"]),
        .testTarget(name: "HistoryTests", dependencies: ["History"]),
    ]
)
