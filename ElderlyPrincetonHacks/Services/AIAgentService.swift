import Foundation
import AVFoundation
import Combine

@MainActor
final class AIAgentService: ObservableObject {
    static let shared = AIAgentService()

    @Published var isSpeaking = false
    @Published var lastSpokenText = ""

    private let synthesizer = AVSpeechSynthesizer()
    private var elevenLabsPlayer: AVAudioPlayer?
    private var speakPromptGeneration: UInt64 = 0

    private init() {}

    var hasAPIKeys: Bool {
        let openAI = UserDefaults.standard.string(forKey: "openai_key") ?? ""
        let k2 = UserDefaults.standard.string(forKey: "k2_think_key") ?? ""
        let elevenLabs = UserDefaults.standard.string(forKey: "elevenlabs_key") ?? ""
        return !elevenLabs.isEmpty && (!openAI.isEmpty || !k2.isEmpty)
    }

    // MARK: - Voice Prompt (Fallback: Apple TTS)

    func speakPrompt(_ text: String) {
        speakPromptGeneration &+= 1
        let gen = speakPromptGeneration
        lastSpokenText = text
        isSpeaking = true

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {}

        synthesizer.speak(utterance)

        Task {
            try? await Task.sleep(for: .seconds(Double(text.count) / 15.0 + 1.0))
            guard gen == speakPromptGeneration else { return }
            isSpeaking = false
        }
    }

    func speakFallDetectionPrompt(userName: String) {
        let prompt = "\(userName), I detected a possible fall. Are you okay? Say yes if you're fine, or say no if you need help."
        speakPrompt(prompt)
    }

    /// Clear phrases improve on-device STT + ElevenLabs Scribe fusion, then K2 reasoning.
    func speakFallCheckPromptAsync(userName: String) async {
        let prompt = """
        \(userName), Guardian detected a possible fall. If you are okay, clearly say: I don't need help. \
        If you need assistance, say: I need help.
        """
        let elevenLabsKey = UserDefaults.standard.string(forKey: "elevenlabs_key") ?? ""
        if !elevenLabsKey.isEmpty {
            await speakWithElevenLabs(prompt)
        } else {
            speakPrompt(prompt)
            try? await Task.sleep(for: .seconds(6))
        }
    }

    func speakEmergencyDispatch(userName: String, location: String) {
        let prompt = "Dispatching emergency services for \(userName) at location \(location). Help is on the way."
        speakPrompt(prompt)
    }

    func stopSpeaking() {
        speakPromptGeneration &+= 1
        synthesizer.stopSpeaking(at: .immediate)
        elevenLabsPlayer?.stop()
        elevenLabsPlayer = nil
        isSpeaking = false
    }

    /// Stops Apple TTS and any ElevenLabs playback (call when user dismisses fall alert).
    func stopAllAudio() {
        stopSpeaking()
    }

    // MARK: - OpenAI Integration (when API key available)

    func generateContextualMessage(event: FallEvent, profile: UserProfile, location: String) async -> String {
        let systemPrompt = """
        You are an emergency medical dispatcher AI. Generate a brief, calm emergency message \
        based on the fall detection data provided. Include the person's name, location, \
        medical conditions, and the severity of the fall. Keep it under 3 sentences.
        """

        let userPrompt = """
        Fall detected for \(profile.name), age \(profile.age).
        Location: \(location).
        Medical info: \(profile.medicalSummary).
        Peak gyroscope reading: \(event.peakGyro.oneDecimal) rad/s.
        Impact acceleration: \(event.peakAcceleration.oneDecimal) g.
        No movement for \(Int(event.stillnessDuration)) seconds.
        Severity: \(event.severity.rawValue).
        """

        let k2Key = UserDefaults.standard.string(forKey: "k2_think_key") ?? ""
        if !k2Key.isEmpty {
            let baseRaw = UserDefaults.standard.string(forKey: "k2_think_base_url") ?? ""
            let base = baseRaw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? Constants.API.k2ThinkDefaultBaseURL
                : baseRaw
            let modelStored = UserDefaults.standard.string(forKey: "k2_think_model") ?? ""
            let model = modelStored.isEmpty ? Constants.API.k2ThinkDefaultModel : modelStored
            if let content = await K2ThinkClient.chatCompletionJSON(
                apiKey: k2Key,
                baseURL: base,
                model: model,
                systemPrompt: systemPrompt,
                userPrompt: userPrompt
            )?.trimmingCharacters(in: .whitespacesAndNewlines),
               !content.isEmpty {
                return content
            }
        }

        let openAIKey = UserDefaults.standard.string(forKey: "openai_key") ?? ""
        guard !openAIKey.isEmpty else {
            return buildFallbackMessage(event: event, profile: profile, location: location)
        }

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
                    ["role": "user", "content": userPrompt]
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
        Emergency alert: \(profile.name.isEmpty ? "User" : profile.name) has experienced a fall \
        at \(location). \(profile.medicalSummary). \
        Severity: \(event.severity.rawValue). No response to voice check. Immediate assistance required.
        """
    }

    // MARK: - ElevenLabs TTS (when API key available)

    func speakWithElevenLabs(_ text: String) async {
        speakPromptGeneration &+= 1
        let gen = speakPromptGeneration

        let elevenLabsKey = UserDefaults.standard.string(forKey: "elevenlabs_key") ?? ""
        guard !elevenLabsKey.isEmpty else {
            speakPrompt(text)
            return
        }

        isSpeaking = true
        lastSpokenText = text

        do {
            let voiceId = "21m00Tcm4TlvDq8ikWAM" // Rachel voice
            let url = URL(string: "\(Constants.API.elevenLabsBaseURL)/text-to-speech/\(voiceId)")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(elevenLabsKey, forHTTPHeaderField: "xi-api-key")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "text": text,
                "model_id": "eleven_monolingual_v1",
                "voice_settings": [
                    "stability": 0.75,
                    "similarity_boost": 0.75
                ]
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: request)

            guard gen == speakPromptGeneration else { return }

            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("tts_output-\(UUID().uuidString).mp3")
            try data.write(to: tempURL)

            let player = try AVAudioPlayer(contentsOf: tempURL)
            elevenLabsPlayer = player
            player.play()

            while player.isPlaying {
                guard gen == speakPromptGeneration else { return }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            try? await Task.sleep(nanoseconds: 150_000_000)
        } catch {
            guard gen == speakPromptGeneration else { return }
            speakPrompt(text)
        }

        if gen == speakPromptGeneration {
            elevenLabsPlayer = nil
            isSpeaking = false
        }
    }
}
