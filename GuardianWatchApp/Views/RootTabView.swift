import SwiftUI

/// Page-style TabView is the canonical watchOS multi-screen pattern.
/// Pages: Status -> Falls -> Gait -> Settings.
struct RootTabView: View {
    @Bindable var state: AppState

    var body: some View {
        TabView(selection: $state.selectedTab) {
            DashboardView(state: state)
                .tag(WatchTab.dashboard)

            HistoryView(state: state)
                .tag(WatchTab.history)

            GaitView(state: state)
                .tag(WatchTab.gait)

            SettingsView(state: state)
                .tag(WatchTab.settings)
        }
        .tabViewStyle(.verticalPage)
        .tint(Theme.accent)
        .fullScreenCover(isPresented: $state.showFallAlert) {
            if let event = state.activeFallEvent {
                FallAlertView(state: state, fallEvent: event)
            }
        }
    }
}
