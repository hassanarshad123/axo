import AppKit
import SwiftUI

/// Shows the island on the notch screen (or the main screen) and moves it when screens change.
@MainActor
public final class NotchController {
    public let model: IslandModel
    private var panel: NotchPanel?
    private var screenObserver: NSObjectProtocol?

    public init(model: IslandModel) {
        self.model = model
    }

    public func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        place(panel)
        panel.orderFrontRegardless()

        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let panel = self.panel else { return }
                self.place(panel)
            }
        }
    }

    public func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NotchPanel {
        let panel = NotchPanel()
        let hosting = IslandHostingView(rootView: BuddyIslandView(model: model))
        hosting.sizingOptions = []
        panel.contentView = hosting
        return panel
    }

    private func place(_ panel: NotchPanel) {
        guard let screen = Self.preferredScreen() else { return }
        let geometry = NotchGeometry.resolve(
            screenFrame: screen.frame,
            safeAreaTop: screen.safeAreaInsets.top,
            auxiliaryTopLeft: screen.auxiliaryTopLeftArea,
            auxiliaryTopRight: screen.auxiliaryTopRightArea
        )
        model.notchSize = geometry.notchRect.size
        panel.setFrame(geometry.panelFrame(maxIslandSize: BuddyIslandView.expandedSize), display: true)
    }

    /// The built-in notch screen if there is one, else the main screen.
    private static func preferredScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }
}

/// The panel never becomes key, so without this the first click only "focuses" it
/// and the user has to click Done or Snooze twice.
final class IslandHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// A see-through window above the menu bar. Clicks on its clear parts go to the windows below.
final class NotchPanel: NSPanel {
    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isFloatingPanel = true
        // Set the level after `isFloatingPanel`, because that property resets the level to `.floating`,
        // which is below the menu bar. The island must draw above the menu bar.
        level = .mainMenu + 1
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// AppKit moves windows below the menu bar by default. The island must touch the top edge.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
