import SwiftUI
import UserNotifications

struct AppRouter: View {
    @Bindable var state: AppState

    var body: some View {
        TabView(selection: $state.selectedTab) {
            Tab(AppTab.dashboard.rawValue, systemImage: AppTab.dashboard.icon, value: .dashboard) {
                MainDashboardView(state: state)
            }

            Tab(AppTab.caregiver.rawValue, systemImage: AppTab.caregiver.icon, value: .caregiver) {
                CaregiverDashboardView(state: state)
            }

            Tab(AppTab.settings.rawValue, systemImage: AppTab.settings.icon, value: .settings) {
                SettingsView(state: state)
            }
        }
        .tint(Theme.accent)
        .fullScreenCover(isPresented: $state.showFallAlert) {
            if let event = state.activeFallEvent {
                FallAlertView(state: state, fallEvent: event)
            }
        }
        .onOpenURL { url in
            guard url.scheme == "guardian", url.host == "cancel-alert" else { return }
            state.dismissFallAlert(outcome: .cancelledByUser)
        }
        .task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        }
    }
}
