import Foundation

/// OpenAI-compatible chat client for Kimi K2 Thinking (or any compatible gateway — set base URL in Settings).
enum K2ThinkClient {

    static func chatCompletionJSON(
        apiKey: String,
        baseURL: String,
        model: String,
        systemPrompt: String,
        userPrompt: String
    ) async -> String? {
        var trimmedBase = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedBase.hasSuffix("/") { trimmedBase.removeLast() }
        guard let url = URL(string: "\(trimmedBase)/chat/completions") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.15,
            "max_tokens": 700
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            guard
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = json["choices"] as? [[String: Any]],
                let message = choices.first?["message"] as? [String: Any]
            else { return nil }

            return message["content"] as? String
        } catch {
            return nil
        }
    }

    static func parseCrisisAssessment(from raw: String) -> CrisisVoiceAssessment? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            text = String(text[start...end])
        }
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(CrisisVoiceAssessment.self, from: data)
    }
}
