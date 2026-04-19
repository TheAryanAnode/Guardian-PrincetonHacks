import Foundation
import WatchConnectivity

/// iPhone <- Watch bridge. Receives fall events that the Apple Watch couldn't
/// upload itself (no Firebase on watchOS) and forwards them to Cloud Firestore
/// via `FallFirestoreService`.
///
/// Activated once at app launch from `GuardianAppDelegate`. Uses
/// `WCSession.transferUserInfo` on the watch side, which guarantees delivery
/// (queues until iPhone is reachable) — so this fires whenever the iPhone
/// wakes, even if the fall happened minutes/hours earlier.
@MainActor
final class WatchConnectivityService: NSObject {
    static let shared = WatchConnectivityService()

    private override init() {
        super.init()
    }

    func activate() {
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

    fileprivate func handle(userInfo: [String: Any]) {
        guard let type = userInfo["type"] as? String, type == "fall_event",
              let eventB64 = userInfo["event_json"] as? String,
              let profileB64 = userInfo["profile_json"] as? String,
              let eventData = Data(base64Encoded: eventB64),
              let profileData = Data(base64Encoded: profileB64) else {
            print("[WatchConnectivity] Ignoring unrecognised payload: \(userInfo)")
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let event = try decoder.decode(FallEvent.self, from: eventData)
            let profile = try decoder.decode(UserProfile.self, from: profileData)
            print("[WatchConnectivity] Received fall \(event.id.uuidString) from watch — forwarding to Firestore")
            FallFirestoreService.shared.syncFallEvent(event, profile: profile)
        } catch {
            print("[WatchConnectivity] Decode error: \(error)")
        }
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error = error {
            print("[WatchConnectivity] iPhone activation error: \(error.localizedDescription)")
        } else {
            print("[WatchConnectivity] iPhone activated. State: \(activationState.rawValue), paired: \(session.isPaired), watchAppInstalled: \(session.isWatchAppInstalled)")
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        Task { @MainActor in
            WatchConnectivityService.shared.handle(userInfo: userInfo)
        }
    }
}
