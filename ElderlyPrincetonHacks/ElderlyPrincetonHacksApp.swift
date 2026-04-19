import SwiftUI

@main
struct ElderlyPrincetonHacksApp: App {
    @UIApplicationDelegateAdaptor(GuardianAppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ZStack {
                Theme.chassis.ignoresSafeArea()

                if appState.showOnboarding {
                    OnboardingView(state: appState)
                        .transition(.move(edge: .bottom))
                } else {
                    AppRouter(state: appState)
                }
            }
            .preferredColorScheme(.light)
        }
    }
}
