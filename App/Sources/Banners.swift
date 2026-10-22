import BuddyCore
import UserNotifications

/// macOS notification banners. Each banner replaces the last one with the same id.
enum Banners {
    static func show(_ prompt: BuddyPrompt) {
        let content = UNMutableNotificationContent()
        content.title = prompt.title
        content.body = prompt.message
        let request = UNNotificationRequest(identifier: prompt.id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
