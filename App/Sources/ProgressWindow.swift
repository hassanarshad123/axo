import AppKit
import BuddyCore
import NotchUI
import SwiftUI

/// Opens the Progress window from the menu ("Progress…").
@MainActor
final class ProgressWindow {
    private var window: NSWindow?

    func show(engine: BuddyEngine) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: ProgressScreen(engine: engine)))
        window.title = "Progress"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 760, height: 720))
        window.contentMinSize = NSSize(width: 700, height: 480)
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}

/// Feeds the dashboard from the engine. It redraws when the progress or the photos change.
private struct ProgressScreen: View {
    let engine: BuddyEngine

    var body: some View {
        TimelineView(.everyMinute) { context in
            ProgressDashboard(
                appearance: engine.appearance,
                state: engine.progress.state,
                now: context.date,
                photos: photos,
                message: engine.progress.problem,
                onDeleteHistory: deleteHistory
            )
        }
    }

    /// Nil hides the photo strip while progress photos are off.
    private var photos: [ProgressPhotoItem]? {
        guard engine.settings.snapshotsEnabled else { return nil }
        let saved = engine.postureMonitor.photos
        _ = saved.count  // Redraw when a photo is saved or deleted.
        return saved.saved().map { ProgressPhotoItem(photo: $0.photo, url: $0.url) }
    }

    private func deleteHistory() {
        engine.progress.deleteAll()
        engine.appearanceChanged()
    }
}
