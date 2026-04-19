import Foundation

enum CrisisReasoningService {

    /// Uses a reasoning-capable model to interpret what the user meant after a fall check-in.
    static func assessVoiceResponse(
        transcript: String,
        fall: FallEvent,
        profile: UserProfile,
        apiKey: String,
        baseURL: String,
        model: String
    ) async -> CrisisVoiceAssessment? {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty, !trimmed.isEmpty else { return nil }

        let system = """
        You are Guardian’s safety reasoning model. After a possible fall, the user spoke a short phrase. \
        Decide what they meant for emergency triage. Prefer literal interpretations of “need help” vs “don’t need help”. \
        Return JSON ONLY (no markdown) with keys: intent (help_needed | all_clear | uncertain), confidence (0-1), \
        caregiverBrief (one sentence for SMS), spokenGuidance (one short sentence to speak aloud to reassure or escalate), \
        reasoningSummary (one sentence, plain language).
        """

        let user = """
        Transcript: "\(trimmed)"
        Fall severity: \(fall.severity.rawValue). Peak user acceleration ~ \(fall.peakAcceleration.oneDecimal) g. \
        Stillness window ~ \(Int(fall.stillnessDuration)) s.
        User: \(profile.name.isEmpty ? "Unknown" : profile.name), age \(profile.age). \
        Medical notes: \(profile.medicalSummary)
        """

        guard let raw = await K2ThinkClient.chatCompletionJSON(
            apiKey: apiKey,
            baseURL: baseURL,
            model: model,
            systemPrompt: system,
            userPrompt: user
        ) else {
            return nil
        }
        return K2ThinkClient.parseCrisisAssessment(from: raw)
    }
}
