import Foundation
import UserNotifications

enum LocalNotificationService {

    /// Fires a time-sensitive local alert when a fall pipeline completes (works when app is backgrounded briefly).
    static func notifyPossibleFall(severity: FallSeverity, peakAcceleration: Double) {
        let content = UNMutableNotificationContent()
        content.title = "Guardian — possible fall"
        content.subtitle = "Severity: \(severity.rawValue)"
        content.body = "We detected motion consistent with a fall. Open the app to respond or cancel dispatch."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "fall-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
