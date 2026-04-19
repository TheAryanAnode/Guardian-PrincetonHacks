import SwiftUI
import WatchKit

/// Entry point for the watchOS app. Pure SwiftUI lifecycle (`@main App`),
/// with a `WKApplicationDelegateAdaptor` that handles background refresh
/// tasks (the watch equivalent of BGTaskScheduler).
@main
struct GuardianWatchApp: App {
    @WKApplicationDelegateAdaptor(GuardianAppDelegate.self) private var delegate
    @State private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                if appState.showOnboarding {
                    OnboardingView(state: appState)
                } else {
                    RootTabView(state: appState)
                }
            }
            .tint(Theme.accent)
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhase(newPhase)
            }
        }
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            // Schedule a refresh so we wake periodically even with monitoring off.
            BackgroundRefreshService.shared.scheduleNextRefresh()
        case .active:
            // No-op: HKWorkoutSession (when active) keeps us live; otherwise
            // we just resume normally.
            break
        case .inactive:
            break
        @unknown default:
            break
        }
    }
}

/// Pure WatchKit delegate to handle background refresh tasks. Only used for
/// the small slice of behavior that SwiftUI scenePhase can't express.
final class GuardianAppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        Task { @MainActor in
            BackgroundRefreshService.shared.scheduleNextRefresh()
            WatchConnectivityService.shared.activateIfPossible()
        }
    }

    func handle(_ backgroundTasks: Set<WKRefreshBackgroundTask>) {
        for task in backgroundTasks {
            switch task {
            case let refreshTask as WKApplicationRefreshBackgroundTask:
                Task { @MainActor in
                    BackgroundRefreshService.shared.handle(refreshTask)
                }
            case let snapshotTask as WKSnapshotRefreshBackgroundTask:
                snapshotTask.setTaskCompleted(
                    restoredDefaultState: true,
                    estimatedSnapshotExpiration: .distantFuture,
                    userInfo: nil
                )
            default:
                task.setTaskCompletedWithSnapshot(false)
            }
        }
    }
}
