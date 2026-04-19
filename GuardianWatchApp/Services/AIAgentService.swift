import Foundation
import AVFoundation
import Combine

/// OpenAI text generation + on-device speech synthesis for watchOS.
///
/// On watchOS the built-in speaker is silent by default unless we explicitly
/// configure an `AVAudioSession` with `.playback` (or `.playAndRecord`) and
/// activate it — otherwise `AVSpeechSynthesizer` outputs to /dev/null.
@MainActor
final class AIAgentService: ObservableObject {
    static let shared = AIAgentService()

    @Published var isSpeaking = false
    @Published var lastSpokenText = ""

    private let synthesizer = AVSpeechSynthesizer()
    private var audioSessionConfigured = false

    private init() {}

    var hasAPIKeys: Bool {
        !(UserDefaults.standard.string(forKey: "openai_key") ?? "").isEmpty
            && !(UserDefaults.standard.string(forKey: "elevenlabs_key") ?? "").isEmpty
    }

    /// Force the audio route to the watch's built-in speaker so spoken prompts
    /// are audible even with the wrist down.
    private func configureAudioSession() {
        guard !audioSessionConfigured else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playback,
                mode: .voicePrompt,
                options: [.duckOthers]
            )
            try session.setActive(true, options: [])
            audioSessionConfigured = true
        } catch {
            print("[AIAgent] Audio session setup failed: \(error)")
        }
    }

    func speakPrompt(_ text: String) {
        configureAudioSession()
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

    /// Plays the canonical prompt heard by the wearer immediately after a
    /// fall is suspected. Personalised when we know the wearer's name.
    func speakFallDetectionPrompt(userName: String) {
        let opener = userName.isEmpty
            ? "I detected a possible fall."
            : "\(userName), I detected a possible fall."
        speakPrompt("\(opener) Tap Get Help if you need help, or tap I'm OK if you want to cancel.")
    }

    /// Shorter reminder used while the countdown is still running so the
    /// wearer hears it more than once.
    func speakFallReminder() {
        speakPrompt("Tap Get Help if you need help, or tap I'm OK to cancel.")
    }

    /// Final urgent message when only a few seconds remain.
    func speakImminentDispatch() {
        speakPrompt("Calling for help now.")
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
