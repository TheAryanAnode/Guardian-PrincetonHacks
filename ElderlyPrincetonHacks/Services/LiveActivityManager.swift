import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<FallDetectionAttributes>?

    private init() {}

    func startMonitoringActivity(userName: String, gaitScore: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = FallDetectionAttributes(userName: userName)
        let state = FallDetectionAttributes.ContentState(
            status: .active,
            gaitScore: gaitScore,
            lastUpdate: .now,
            alertActive: false,
            countdown: nil
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            // Activity may fail if extension missing or Live Activities disabled
        }
    }

    func updateActivity(status: MonitoringStatus, gaitScore: Int, alertActive: Bool = false, countdown: Int? = nil) {
        let state = FallDetectionAttributes.ContentState(
            status: status,
            gaitScore: gaitScore,
            lastUpdate: .now,
            alertActive: alertActive,
            countdown: countdown
        )

        Task {
            await currentActivity?.update(.init(state: state, staleDate: nil))
        }
    }

    func endActivity() {
        let state = FallDetectionAttributes.ContentState(
            status: .inactive,
            gaitScore: 0,
            lastUpdate: .now,
            alertActive: false,
            countdown: nil
        )

        Task {
            await currentActivity?.end(.init(state: state, staleDate: nil), dismissalPolicy: .immediate)
            currentActivity = nil
        }
    }
}
