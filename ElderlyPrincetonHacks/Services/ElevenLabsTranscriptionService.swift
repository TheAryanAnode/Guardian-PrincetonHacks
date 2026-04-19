import Foundation

enum ElevenLabsTranscriptionService {

    /// Uploads a local audio file (e.g. `.caf` from `AVAudioFile`) to ElevenLabs Scribe.
    static func transcribe(fileURL: URL, apiKey: String) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: URL(string: "\(Constants.API.elevenLabsBaseURL)/speech-to-text")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func appendLine(_ s: String) { body.append(Data(s.utf8)) }

        let fileData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent

        appendLine("--\(boundary)\r\n")
        appendLine("Content-Disposition: form-data; name=\"model_id\"\r\n\r\n")
        appendLine("\(Constants.API.elevenLabsSTTModelId)\r\n")

        appendLine("--\(boundary)\r\n")
        appendLine("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        appendLine("Content-Type: application/octet-stream\r\n\r\n")
        body.append(fileData)
        appendLine("\r\n")

        appendLine("--\(boundary)--\r\n")
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        if let text = json["text"] as? String { return text }
        if let transcripts = json["transcripts"] as? [[String: Any]],
           let first = transcripts.first,
           let text = first["text"] as? String {
            return text
        }
        throw URLError(.cannotParseResponse)
    }
}
