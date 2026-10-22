import AppKit
import BuddyCore
import SwiftUI

/// Shows a full-screen break on every screen, above all apps and on every Space.
///
///     show(session) ──▶ one panel per screen; the main screen's panel takes the keys
///         Esc (can skip)            ──▶ onSkip
///         Esc held 3 s (locked)     ──▶ onEmergencyExit
///         "Hold to leave" held 3 s  ──▶ onEmergencyExit
///     hide() ──▶ panels gone, key watch removed
///
/// The panels never activate the app (no `presentationOptions`). A menu bar app may not get focus
/// on macOS 14, but a non-activating panel that can become key still gets Esc.
@MainActor
public final class BreakScreens {
    public var onSkip: () -> Void = {}
    public var onEmergencyExit: () -> Void = {}

    private var model: BreakScreenModel?
    private var panels: [BreakPanel] = []
    private var keyMonitor: Any?
    private var screenObserver: NSObjectProtocol?
    private var exitTask: Task<Void, Never>?

    private static let escapeKeyCode: UInt16 = 53

    public init() {}

    public var isShowing: Bool { model != nil }

    public func show(_ session: BreakSession, appearance: BuddyAppearance) {
        hide()
        model = BreakScreenModel(session: session, appearance: appearance)
        makePanels()
        watchKeys()
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.makePanels() }
        }
    }

    public func hide() {
        exitTask?.cancel()
        exitTask = nil
        panels.forEach { $0.orderOut(nil) }
        panels = []
        model = nil
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        keyMonitor = nil
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
        screenObserver = nil
    }

    /// One panel for each screen. Called again when screens are added or removed.
    private func makePanels() {
        panels.forEach { $0.orderOut(nil) }
        guard let model else {
            panels = []
            return
        }
        panels = NSScreen.screens.map { screen in
            let panel = BreakPanel(frame: screen.frame)
            let view = BreakScreenView(
                model: model,
                onSkip: { [weak self] in self?.onSkip() },
                onExit: { [weak self] in self?.onEmergencyExit() }
            )
            let hosting = IslandHostingView(rootView: view)
            hosting.sizingOptions = []
            panel.contentView = hosting
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()
            return panel
        }
        // The main screen's panel takes the keys: Esc reaches us, and typing does not go to the app behind.
        (panels.first { $0.screen == NSScreen.main } ?? panels.first)?.makeKey()
    }

    private func watchKeys() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            MainActor.assumeIsolated {
                self?.handle(event)
            }
            return nil  // While the break shows, no key goes anywhere else.
        }
    }

    private func handle(_ event: NSEvent) {
        guard event.keyCode == Self.escapeKeyCode, let model else { return }
        if model.session.canSkip {
            if event.type == .keyDown { onSkip() }
            return
        }
        switch event.type {
        case .keyDown where !event.isARepeat:
            startExitHold(model)
        case .keyUp:
            exitTask?.cancel()
            exitTask = nil
            model.exitHeldSince = nil
        default:
            break
        }
    }

    private func startExitHold(_ model: BreakScreenModel) {
        model.exitHeldSince = Date()
        exitTask?.cancel()
        exitTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(BreakSession.emergencyExitHold))
            } catch {
                return  // Esc was let go.
            }
            self?.onEmergencyExit()
        }
    }
}

/// A borderless panel over a whole screen, above the menu bar, the Dock and full-screen apps.
final class BreakPanel: NSPanel {
    init(frame: NSRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isFloatingPanel = true
        // After `isFloatingPanel`, which resets the level. Screen saver level is above the menu bar and the Dock.
        level = .screenSaver
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Cover the menu bar too.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
