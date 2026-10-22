import AppKit
import Observation
import Sparkle

/// Checks for new versions with Sparkle (docs/PRIVACY.md, rule 7).
///
///     once a day (switch on) ─┐
///     "Check for Updates…" ───┴─▶ Sparkle ─▶ https://axo.zensbot.com/appcast.xml
///
/// The update list, the public key and the daily check are Info.plist keys in `project.yml`.
/// Sparkle installs only an update signed with the Axo EdDSA key (docs/RELEASE.md).
///
/// Axo has no Dock icon, so a window that jumps up during work would be rude. When the daily
/// check finds an update later in the day, the menu shows "Install version …" instead.
/// Near launch, Sparkle shows its own window (a gentle reminder in Sparkle's terms).
@MainActor
@Observable
final class AppUpdater: NSObject {
    /// The version that waits for the user, found by the daily check. Nil = nothing waits.
    private(set) var waitingVersion: String?
    /// "Check for updates automatically" in Settings > General.
    var checksAutomatically: Bool {
        didSet { controller?.updater.automaticallyChecksForUpdates = checksAutomatically }
    }

    @ObservationIgnored private var controller: SPUStandardUpdaterController?

    override init() {
        checksAutomatically = true
        super.init()
        let controller = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: self)
        self.controller = controller
        checksAutomatically = controller.updater.automaticallyChecksForUpdates
    }

    /// The menu button. Shows the waiting update, or checks now and says if there is none.
    func checkForUpdates() {
        NSApp.activate()  // A menu bar app is not in front, and Sparkle's window must be.
        controller?.checkForUpdates(nil)
    }
}

extension AppUpdater: @preconcurrency SPUStandardUserDriverDelegate {
    var supportsGentleScheduledUpdateReminders: Bool { true }

    /// Near launch, Sparkle shows the update. Later in the day, the menu shows it.
    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem, andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool, forUpdate update: SUAppcastItem, state: SPUUserUpdateState
    ) {
        guard !handleShowingUpdate else { return }
        waitingVersion = update.displayVersionString
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        waitingVersion = nil
    }

    func standardUserDriverWillFinishUpdateSession() {
        waitingVersion = nil
    }
}
