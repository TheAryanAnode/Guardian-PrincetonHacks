import Foundation

/// Syncs resolved fall events to Cloud Firestore using the REST API + Firebase Anonymous Auth
/// (no Firebase iOS SDK — avoids heavy SPM / xcframework downloads).
///
/// **Firebase Console:** Enable *Authentication → Sign-in method → Anonymous*.
/// **GoogleService-Info.plist** must be in the app bundle (API_KEY + PROJECT_ID).
final class FallFirestoreService {
    static let shared = FallFirestoreService()

    private let collectionId = "fall_events"
    private let ud = UserDefaults.standard

    private enum Keys {
        static let idToken = "firebase_rest_id_token"
        static let refreshToken = "firebase_rest_refresh_token"
        static let tokenExpiry = "firebase_rest_token_expiry"
    }

    private init() {}

    func syncFallEvent(_ event: FallEvent, profile: UserProfile) {
        Task {
            await upload(event: event, profile: profile)
        }
    }

    private func upload(event: FallEvent, profile: UserProfile) async {
        guard let cfg = FirebaseRESTConfig.loadFromBundle() else {
            #if DEBUG
            print("FallFirestoreService: GoogleService-Info.plist missing or invalid")
            #endif
            return
        }

        do {
            let idToken = try await ensureIdToken(cfg: cfg)
            let url = firestoreCreateURL(projectId: cfg.projectId, documentId: event.id.uuidString)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: Any] = ["fields": firestoreFields(event: event, profile: profile)]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }
            if (200...299).contains(http.statusCode) {
                #if DEBUG
                print("FallFirestoreService: OK — fall_events/\(event.id.uuidString) written")
                #endif
            } else {
                let body = String(data: data, encoding: .utf8) ?? ""
                #if DEBUG
                print("FallFirestoreService: HTTP \(http.statusCode) \(body)")
                #endif
            }
        } catch {
            clearStoredTokensIfConfigurationError(error)
            #if DEBUG
            print("FallFirestoreService: \(error.localizedDescription)")
            #endif
        }
    }

    private func firestoreCreateURL(projectId: String, documentId: String) -> URL {
        var c = URLComponents(string: "https://firestore.googleapis.com/v1/projects/\(projectId)/databases/(default)/documents/\(collectionId)")!
        c.queryItems = [URLQueryItem(name: "documentId", value: documentId)]
        return c.url!
    }

    // MARK: - Auth (Anonymous)

    private func ensureIdToken(cfg: FirebaseRESTConfig) async throws -> String {
        let now = Date().timeIntervalSince1970
        if let token = ud.string(forKey: Keys.idToken),
           let exp = ud.object(forKey: Keys.tokenExpiry) as? TimeInterval,
           now < exp - 120 {
            return token
        }

        if let refresh = ud.string(forKey: Keys.refreshToken), !refresh.isEmpty {
            return try await refreshIdToken(cfg: cfg, refreshToken: refresh)
        }

        return try await signUpAnonymous(cfg: cfg)
    }

    private func signUpAnonymous(cfg: FirebaseRESTConfig) async throws -> String {
        let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=\(cfg.apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyIdentityToolkitHeaders(&request, cfg: cfg)
        request.httpBody = try JSONSerialization.data(withJSONObject: ["returnSecureToken": true])

        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfHTTPError(response, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idToken = json["idToken"] as? String,
              let refresh = json["refreshToken"] as? String else {
            throw URLError(.cannotParseResponse)
        }
        let seconds = parseExpiresIn(json["expiresIn"]) ?? 3600

        storeTokens(idToken: idToken, refreshToken: refresh, expiresInSeconds: seconds)
        return idToken
    }

    private func refreshIdToken(cfg: FirebaseRESTConfig, refreshToken: String) async throws -> String {
        let url = URL(string: "https://securetoken.googleapis.com/v1/token?key=\(cfg.apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        applyIdentityToolkitHeaders(&request, cfg: cfg)
        let body = "grant_type=refresh_token&refresh_token=\(refreshToken.percentFormEncoded)"
        request.httpBody = Data(body.utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        try throwIfHTTPError(response, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let idToken = json["id_token"] as? String,
              let refresh = json["refresh_token"] as? String else {
            throw URLError(.cannotParseResponse)
        }
        let seconds = parseExpiresIn(json["expires_in"]) ?? 3600

        storeTokens(idToken: idToken, refreshToken: refresh, expiresInSeconds: seconds)
        return idToken
    }

    /// Identity Toolkit often returns `CONFIGURATION_NOT_FOUND` (400) without the iOS bundle ID header.
    private func applyIdentityToolkitHeaders(_ request: inout URLRequest, cfg: FirebaseRESTConfig) {
        if let bid = Bundle.main.bundleIdentifier {
            request.setValue(bid, forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        }
        if let gmp = cfg.googleAppID {
            request.setValue(gmp, forHTTPHeaderField: "X-Firebase-GMPID")
        }
    }

    private func parseExpiresIn(_ value: Any?) -> Double? {
        if let i = value as? Int { return Double(i) }
        if let d = value as? Double { return d }
        if let s = value as? String { return Double(s) }
        return nil
    }

    private func storeTokens(idToken: String, refreshToken: String, expiresInSeconds: Double) {
        ud.set(idToken, forKey: Keys.idToken)
        ud.set(refreshToken, forKey: Keys.refreshToken)
        ud.set(Date().timeIntervalSince1970 + expiresInSeconds, forKey: Keys.tokenExpiry)
    }

    private func throwIfHTTPError(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw NSError(
                domain: "FallFirestoreService",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: msg]
            )
        }
    }

    /// After a bad token/config, drop cached auth so the next sync retries anonymous sign-up with fresh headers.
    private func clearStoredTokensIfConfigurationError(_ error: Error) {
        let text = (error as NSError).userInfo[NSLocalizedDescriptionKey] as? String ?? ""
        if text.contains("CONFIGURATION_NOT_FOUND") {
            ud.removeObject(forKey: Keys.idToken)
            ud.removeObject(forKey: Keys.refreshToken)
            ud.removeObject(forKey: Keys.tokenExpiry)
        }
    }

    // MARK: - Firestore document encoding

    private func firestoreFields(event: FallEvent, profile: UserProfile) -> [String: [String: Any]] {
        var fields: [String: [String: Any]] = [
            "id": fsString(event.id.uuidString),
            "timestamp": fsTimestamp(event.timestamp),
            "severity": fsString(event.severity.rawValue),
            "peakGyro": fsDouble(event.peakGyro),
            "peakAcceleration": fsDouble(event.peakAcceleration),
            "stillnessDuration": fsDouble(event.stillnessDuration),
            "voiceResponseReceived": fsBool(event.voiceResponseReceived),
            "userName": fsString(profile.name),
            "userAge": fsDouble(Double(profile.age)),
            "medicalSummary": fsString(profile.medicalSummary),
            "triggers": fsArray(event.triggers.map { t in
                fsMap([
                    "description": fsString(t.description),
                    "value": fsString(t.value),
                    "icon": fsString(t.icon)
                ])
            }),
            "timeline": fsArray(event.timelineEntries.map { e in
                fsMap([
                    "event": fsString(e.event),
                    "detail": fsString(e.detail),
                    "timestamp": fsTimestamp(e.timestamp)
                ])
            })
        ]

        if let outcome = event.outcome {
            fields["outcome"] = fsString(outcome.rawValue)
        }
        if let lat = event.latitude { fields["latitude"] = fsDouble(lat) }
        if let lon = event.longitude { fields["longitude"] = fsDouble(lon) }
        if let ac = event.audioConfidence { fields["audioConfidence"] = fsDouble(ac) }
        if let voice = event.voiceResponse { fields["voiceResponse"] = fsString(voice) }

        return fields
    }

    private func fsString(_ s: String) -> [String: Any] { ["stringValue": s] }
    private func fsDouble(_ d: Double) -> [String: Any] { ["doubleValue": d] }
    private func fsBool(_ b: Bool) -> [String: Any] { ["booleanValue": b] }

    private func fsTimestamp(_ date: Date) -> [String: Any] {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return ["timestampValue": f.string(from: date)]
    }

    private func fsMap(_ inner: [String: [String: Any]]) -> [String: Any] {
        ["mapValue": ["fields": inner]]
    }

    private func fsArray(_ values: [[String: Any]]) -> [String: Any] {
        ["arrayValue": ["values": values]]
    }
}

// MARK: - Config

private struct FirebaseRESTConfig {
    let apiKey: String
    let projectId: String
    let googleAppID: String?

    static func loadFromBundle() -> FirebaseRESTConfig? {
        guard let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any],
              let apiKey = dict["API_KEY"] as? String,
              let projectId = dict["PROJECT_ID"] as? String,
              !apiKey.isEmpty,
              !projectId.isEmpty else {
            return nil
        }
        let gmp = dict["GOOGLE_APP_ID"] as? String
        return FirebaseRESTConfig(apiKey: apiKey, projectId: projectId, googleAppID: gmp)
    }
}

private extension String {
    var percentFormEncoded: String {
        addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? self
    }
}
