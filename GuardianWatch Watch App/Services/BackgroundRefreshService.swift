import Foundation
import WatchKit
import UserNotifications

/// watchOS analogue of the iOS BackgroundMonitorService.
///
/// On iOS we used `BGTaskScheduler` (BGAppRefreshTask / BGProcessingTask) — those
/// don't exist on the watch. Instead we schedule periodic background refreshes
/// via `WKApplication.shared().scheduleBackgroundRefresh(...)` and handle them
/// in our `WKApplicationDelegate`.
///
/// During an active HKWorkoutSession (see WorkoutSessionManager) the app stays
/// foreground-eligible, so this is mainly used when monitoring is paused.
@MainActor
final class BackgroundRefreshService {
    static let shared = BackgroundRefreshService()

    private init() {}

    func scheduleNextRefresh(after interval: TimeInterval = 15 * 60) {
        let preferred = Date(timeIntervalSinceNow: interval)
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: preferred,
            userInfo: nil
        ) { _ in }
    }

    func handle(_ task: WKApplicationRefreshBackgroundTask) {
        scheduleNextRefresh()

        if let record = GaitAnalysisService.shared.analyzeGait() {
            sendGaitNotificationIfNeeded(record: record)
        }

        task.setTaskCompletedWithSnapshot(false)
    }

    private func sendGaitNotificationIfNeeded(record: GaitRecord) {
        guard record.riskLevel == .high else { return }
        let content = UNMutableNotificationContent()
        content.title = "Gait Alert"
        content.body  = "Walking stability dropped to \(Int(record.overallScore)). Fall risk elevated."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
