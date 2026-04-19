import Foundation
import WatchConnectivity

/// Watch -> iPhone bridge. Sends resolved fall events to the paired iPhone via
/// `WCSession.transferUserInfo`, which guarantees delivery (queues on disk
/// until the iPhone is reachable). The iPhone then forwards the event to
/// Cloud Firestore using `FallFirestoreService`.
@MainActor
final class WatchConnectivityService: NSObject {
    static let shared = WatchConnectivityService()

    private override init() {
        super.init()
        activateIfPossible()
    }

    func activateIfPossible() {
        guard WCSession.isSupported() else {
            print("[WatchConnectivity] WCSession not supported on this device")
            return
        }
        let session = WCSession.default
        session.delegate = self
        if session.activationState != .activated {
            session.activate()
        }
    }

    func sendFallEvent(_ event: FallEvent, profile: UserProfile) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        if session.activationState != .activated {
            session.activate()
        }

        do {
            let payload = try makePayload(event: event, profile: profile)
            session.transferUserInfo(payload)
            print("[WatchConnectivity] Queued fall event \(event.id.uuidString) for iPhone")
        } catch {
            print("[WatchConnectivity] Failed to encode payload: \(error)")
        }
    }

    private func makePayload(event: FallEvent, profile: UserProfile) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let eventData = try encoder.encode(event)
        let profileData = try encoder.encode(profile)

        return [
            "type": "fall_event",
            "event_json": eventData.base64EncodedString(),
            "profile_json": profileData.base64EncodedString(),
            "source": "watch"
        ]
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error = error {
            print("[WatchConnectivity] Activation error: \(error.localizedDescription)")
        } else {
            print("[WatchConnectivity] Activated. State: \(activationState.rawValue), reachable: \(session.isReachable), companion installed: \(session.isCompanionAppInstalled)")
        }
    }
}
