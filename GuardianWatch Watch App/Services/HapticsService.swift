import WatchKit

/// Thin wrapper over WKInterfaceDevice haptics.
/// We use this everywhere the iOS build relied on Live Activities or AVSpeech alerts.
@MainActor
enum HapticsService {
    static func play(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }

    static func fallAlert() {
        // Strong attention pattern: failure pulse + notification ring.
        play(.failure)
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            play(.notification)
            try? await Task.sleep(for: .milliseconds(250))
            play(.notification)
        }
    }

    static func dispatchTriggered() {
        play(.directionUp)
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            play(.success)
        }
    }

    static func cancelled() {
        play(.success)
    }

    static func tick() {
        play(.click)
    }
}
