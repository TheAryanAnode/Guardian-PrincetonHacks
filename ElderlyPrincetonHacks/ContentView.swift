import SwiftUI

struct ContentView: View {
    @State private var appState = AppState()

    var body: some View {
        AppRouter(state: appState)
            .preferredColorScheme(.light)
    }
}

#Preview {
    ContentView()
}
