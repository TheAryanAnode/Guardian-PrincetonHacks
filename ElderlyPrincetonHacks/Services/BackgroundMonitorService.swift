import Foundation
import BackgroundTasks
import UserNotifications

@MainActor
final class BackgroundMonitorService {
    static let shared = BackgroundMonitorService()

    static let refreshTaskID = "com.guardian.refresh"
    static let processingTaskID = "com.guardian.gait-processing"

    private init() {}

    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshTaskID,
            using: nil
        ) { task in
            Task { @MainActor in
                self.handleAppRefresh(task as! BGAppRefreshTask)
            }
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.processingTaskID,
            using: nil
        ) { task in
            Task { @MainActor in
                self.handleGaitProcessing(task as! BGProcessingTask)
            }
        }
    }

    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    func scheduleGaitProcessing() {
        let request = BGProcessingTaskRequest(identifier: Self.processingTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        request.requiresExternalPower = false
        request.requiresNetworkConnectivity = false
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleAppRefresh(_ task: BGAppRefreshTask) {
        scheduleAppRefresh()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        task.setTaskCompleted(success: true)
    }

    private func handleGaitProcessing(_ task: BGProcessingTask) {
        scheduleGaitProcessing()

        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }

        if let record = GaitAnalysisService.shared.analyzeGait() {
            sendGaitNotificationIfNeeded(record: record)
        }

        task.setTaskCompleted(success: true)
    }

    private func sendGaitNotificationIfNeeded(record: GaitRecord) {
        guard record.riskLevel == .high else { return }

        let content = UNMutableNotificationContent()
        content.title = "Gait Alert"
        content.body = "Your walking stability score has dropped to \(Int(record.overallScore)). Fall risk may be elevated."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
