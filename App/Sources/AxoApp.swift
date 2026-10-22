import AppKit
import NotchUI
import SwiftUI
import UserNotifications

@main
struct AxoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(
                engine: appDelegate.engine, updater: appDelegate.updater, openSetup: appDelegate.showSetup,
                openProgress: appDelegate.showProgress)
        } label: {
            // The buddy's own icon (Settings > Buddy > Menu bar icon), or a mood symbol while
            // the outline art does not exist yet.
            if let icon = appDelegate.engine.menuBarImage {
                Image(nsImage: icon)
            } else {
                Image(systemName: appDelegate.engine.menuBarSymbol)
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(engine: appDelegate.engine, settings: appDelegate.settings, updater: appDelegate.updater)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings: SettingsStore
    let engine: BuddyEngine
    let updater = AppUpdater()
    private let notch: NotchController
    private let onboarding = OnboardingWindow()
    private let progressWindow = ProgressWindow()

    override init() {
        let settings = SettingsStore()
        // Before the engine first reads the catalog, so a saved locked buddy shows from the start.
        for code in settings.unlockCodes {
            BuddySprites.shared.unlock(code)
        }
        let island = IslandModel()
        self.settings = settings
        engine = BuddyEngine(settings: settings, island: island)
        notch = NotchController(model: island)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        notch.show()
        engine.start()
        if settings.hasFinishedOnboarding {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        } else {
            showSetup()  // The setup window asks for notifications at the right moment.
        }
    }

    func showSetup() {
        onboarding.show(engine: engine, settings: settings)
    }

    func showProgress() {
        progressWindow.show(engine: engine)
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine.stop()
    }
}
