import Foundation
import AVFoundation
import Combine

/// Same OpenAI/ElevenLabs adapter as iOS, minus the AVAudioSession dance
/// (watchOS handles audio routing automatically through the workout session).
/// AVSpeechSynthesizer is supported on watchOS 7+.
@MainActor
final class AIAgentService: ObservableObject {
    static let shared = AIAgentService()

    @Published var isSpeaking = false
    @Published var lastSpokenText = ""

    private let synthesizer = AVSpeechSynthesizer()

    private init() {}

    var hasAPIKeys: Bool {
        !(UserDefaults.standard.string(forKey: "openai_key") ?? "").isEmpty
            && !(UserDefaults.standard.string(forKey: "elevenlabs_key") ?? "").isEmpty
    }

    func speakPrompt(_ text: String) {
        lastSpokenText = text
        isSpeaking = true

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        synthesizer.speak(utterance)

        Task {
            try? await Task.sleep(for: .seconds(Double(text.count) / 15.0 + 1.0))
            isSpeaking = false
        }
    }

    func speakFallDetectionPrompt(userName: String) {
        speakPrompt("\(userName), I detected a possible fall. Tap I'm OK or Get Help.")
    }

    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }

    func generateContextualMessage(event: FallEvent, profile: UserProfile, location: String) async -> String {
        let openAIKey = UserDefaults.standard.string(forKey: "openai_key") ?? ""
        guard !openAIKey.isEmpty else {
            return buildFallbackMessage(event: event, profile: profile, location: location)
        }

        let systemPrompt = "You are an emergency medical dispatcher AI. Generate a brief, calm emergency message including the person's name, location, medical conditions, and severity. Keep it under 3 sentences."
        let userPrompt = """
        Fall detected for \(profile.name), age \(profile.age).
        Location: \(location).
        Medical info: \(profile.medicalSummary).
        Peak gyro: \(event.peakGyro.oneDecimal) rad/s.
        Impact: \(event.peakAcceleration.oneDecimal) g.
        No movement for \(Int(event.stillnessDuration)) s.
        Severity: \(event.severity.rawValue).
        """

        do {
            let url = URL(string: "\(Constants.API.openAIBaseURL)/chat/completions")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "model": "gpt-4o-mini",
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user",   "content": userPrompt]
                ],
                "max_tokens": 150,
                "temperature": 0.3
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content
            }
        } catch {}

        return buildFallbackMessage(event: event, profile: profile, location: location)
    }

    private func buildFallbackMessage(event: FallEvent, profile: UserProfile, location: String) -> String {
        """
        Emergency: \(profile.name.isEmpty ? "User" : profile.name) may have fallen at \(location). \
        \(profile.medicalSummary). Severity: \(event.severity.rawValue). \
        No response received. Immediate assistance required.
        """
    }
}
