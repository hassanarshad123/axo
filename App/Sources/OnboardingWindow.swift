import AppKit
import SwiftUI

/// Opens the setup window: at the first start, and from the menu ("Setup guide…").
@MainActor
final class OnboardingWindow {
    private var window: NSWindow?

    func show(engine: BuddyEngine, settings: SettingsStore) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        let view = OnboardingView(engine: engine, settings: settings) { [weak self] in
            engine.setupFinished()
            self?.close()
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Welcome to Axo"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func close() {
        window?.close()
        window = nil
    }
}
