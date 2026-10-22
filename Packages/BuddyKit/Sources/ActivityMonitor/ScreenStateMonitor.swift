import AppKit

/// Knows if the screen is locked, the display sleeps, the Mac sleeps, or another user is switched in.
/// Raw signal only: BuddyCore decides what it means (`ActivityState.resolve`, `PostureCheckPolicy`).
///
/// The app makes one monitor and keeps it for its whole life. Call `stop()` before you drop one.
@MainActor
public final class ScreenStateMonitor {
    private enum Reason: Hashable {
        case systemAsleep
        case displayAsleep
        case locked
        /// Fast user switching: another user has the screen.
        case sessionInactive
    }

    private var reasons: Set<Reason> = []
    private var observers: [(center: NotificationCenter, token: NSObjectProtocol)] = []

    /// Called on the main thread each time `isLockedOrAsleep` changes.
    public var onChange: (Bool) -> Void = { _ in }

    public init() {}

    /// True while nobody can use the Mac: locked, display off, asleep, or another user is active.
    public var isLockedOrAsleep: Bool { !reasons.isEmpty }

    public func start() {
        guard observers.isEmpty else { return }
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.willSleepNotification, .systemAsleep, isActive: true)
        observe(workspace, NSWorkspace.didWakeNotification, .systemAsleep, isActive: false)
        observe(workspace, NSWorkspace.screensDidSleepNotification, .displayAsleep, isActive: true)
        observe(workspace, NSWorkspace.screensDidWakeNotification, .displayAsleep, isActive: false)
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification, .sessionInactive, isActive: true)
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification, .sessionInactive, isActive: false)

        // Not in the SDK as constants, but sent by macOS for many years. Read-only, no permission needed.
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked"), .locked, isActive: true)
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked"), .locked, isActive: false)
    }

    public func stop() {
        for observer in observers {
            observer.center.removeObserver(observer.token)
        }
        observers = []
        reasons = []
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, _ reason: Reason, isActive: Bool) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.set(reason, isActive: isActive)
            }
        }
        observers.append((center, token))
    }

    private func set(_ reason: Reason, isActive: Bool) {
        let wasLockedOrAsleep = isLockedOrAsleep
        if isActive {
            reasons.insert(reason)
        } else {
            reasons.remove(reason)
        }
        if isLockedOrAsleep != wasLockedOrAsleep {
            onChange(isLockedOrAsleep)
        }
    }
}
