import Foundation
import AVFoundation
import Speech
import Combine

@MainActor
final class AudioClassificationService: ObservableObject {
    static let shared = AudioClassificationService()

    @Published var isListening = false
    @Published var audioConfidence: Double = 0
    @Published var detectedSpeech: String = ""
    @Published var impactDetected = false

    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recordingFile: AVAudioFile?
    private var recordingURL: URL?

    private init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }

    func requestPermissions() async -> Bool {
        guard speechRecognizer != nil else { return false }

        let speechAuth = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }

        let audioAuth: Bool
        if #available(iOS 17.0, *) {
            audioAuth = await AVAudioApplication.requestRecordPermission()
        } else {
            audioAuth = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }

        return speechAuth && audioAuth
    }

    /// Capture audio for impact detection and voice response
    func startListening(duration: TimeInterval = Constants.Alert.audioCaptureDuration) async -> AudioResult {
        stopListening()
        isListening = true
        impactDetected = false
        detectedSpeech = ""

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            isListening = false
            return AudioResult(impactDetected: false, speechDetected: nil, confidence: 0)
        }

        audioEngine = AVAudioEngine()
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let audioEngine, let recognitionRequest else {
            isListening = false
            return AudioResult(impactDetected: false, speechDetected: nil, confidence: 0)
        }

        recognitionRequest.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)

        recordingFile = nil
        let captureURL = FileManager.default.temporaryDirectory.appendingPathComponent("guardian-voice-\(UUID().uuidString).caf")
        recordingURL = captureURL
        recordingFile = try? AVAudioFile(forWriting: captureURL, settings: recordingFormat.settings)

        var peakAmplitude: Float = 0

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
            try? self.recordingFile?.write(from: buffer)

            let channelData = buffer.floatChannelData?[0]
            let frameLength = Int(buffer.frameLength)
            if let data = channelData {
                for i in 0..<frameLength {
                    let amplitude = abs(data[i])
                    if amplitude > peakAmplitude {
                        peakAmplitude = amplitude
                    }
                }
            }
        }

        do {
            try audioEngine.start()
        } catch {
            isListening = false
            return AudioResult(impactDetected: false, speechDetected: nil, confidence: 0)
        }

        var finalTranscription: String?

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, _ in
            if let result {
                finalTranscription = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.detectedSpeech = result.bestTranscription.formattedString
                }
            }
        }

        try? await Task.sleep(for: .seconds(duration))

        audioEngine.stop()
        inputNode.removeTap(onBus: 0)
        recognitionRequest.endAudio()
        recognitionTask?.cancel()

        let hasImpact = peakAmplitude > 0.8
        let confidence = min(Double(peakAmplitude) * 1.5, 1.0)

        isListening = false
        impactDetected = hasImpact
        audioConfidence = confidence

        recordingFile = nil

        let appleLine = (finalTranscription ?? detectedSpeech)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let elevenKey = UserDefaults.standard.string(forKey: "elevenlabs_key") ?? ""
        var merged = appleLine
        if !elevenKey.isEmpty, let url = recordingURL, FileManager.default.fileExists(atPath: url.path) {
            if let elText = try? await ElevenLabsTranscriptionService.transcribe(fileURL: url, apiKey: elevenKey) {
                let trimmed = elText.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.count >= merged.count {
                    merged = trimmed
                }
            }
            try? FileManager.default.removeItem(at: url)
        }
        recordingURL = nil

        let speechOut: String? = merged.isEmpty ? nil : merged

        return AudioResult(
            impactDetected: hasImpact,
            speechDetected: speechOut,
            confidence: confidence
        )
    }

    func stopListening() {
        audioEngine?.stop()
        if let audioEngine {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine = nil
        recordingFile = nil
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        recordingURL = nil
        isListening = false
    }
}

struct AudioResult {
    let impactDetected: Bool
    let speechDetected: String?
    let confidence: Double

    var containsHelpRequest: Bool {
        let speech = speechDetected?.lowercased() ?? ""
        if speech.contains("don't need help") || speech.contains("dont need help") || speech.contains("do not need help") {
            return false
        }
        if speech.contains("i need help") || speech.contains("need help") || speech.contains("send help") {
            return true
        }
        let helpKeywords = ["fallen", "hurt", "pain", "emergency", "ambulance", "call 911", "call for help"]
        return helpKeywords.contains { speech.contains($0) }
    }

    var containsDismissal: Bool {
        let speech = speechDetected?.lowercased() ?? ""
        if speech.contains("don't need help") || speech.contains("dont need help") || speech.contains("do not need help") {
            return true
        }
        let okKeywords = [
            "yes", "yeah", "yep", "okay", "ok", "fine", "i'm fine", "im fine",
            "i'm ok", "im ok", "good", "alright", "all good", "false alarm"
        ]
        return okKeywords.contains { speech.contains($0) }
    }
}
