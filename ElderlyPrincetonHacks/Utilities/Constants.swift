import Foundation

nonisolated(unsafe)
enum Constants {

    enum Motion {
        static let updateInterval: TimeInterval = 1.0 / 100.0 // 100Hz
        /// Lower = easier to trigger during demos (rotation spike).
        static let gyroRotationThreshold: Double = 0.45        // rad/s
        static let impactAccelThreshold: Double = 0.95         // g-force (after rotation spike)
        static let stillnessThreshold: Double = 0.2            // g-force variance
        /// Shorter window makes the “rotation then impact” path easier to complete in testing.
        static let stillnessDuration: TimeInterval = 3.25      // seconds
        static let falsePositiveWindow: TimeInterval = 1.15    // seconds between rotation + impact
        static let gaitWindowDuration: TimeInterval = 30.0     // seconds of data for gait analysis
        static let quickTriggerImpactThreshold: Double = 1.05  // g-force, impact-first path
        static let quickTriggerWindow: TimeInterval = 0.85     // seconds to look for rotation around impact
        /// High-energy events (shake / slam) use shorter “settle” time so the alert can fire after you stop moving.
        static let violentImpactThreshold: Double = 1.85
        static let violentGyroThreshold: Double = 2.4
        static let shortStillnessDuration: TimeInterval = 1.1
        /// While waiting for stillness: movement above this (user accel, g) cancels and restarts detection.
        static let stillnessInterruptThreshold: Double = 0.55
        static let violentStillnessInterruptThreshold: Double = 1.35
    }

    enum Alert {
        static let countdownDuration: Int = 30                 // seconds before auto-dispatch
        static let audioCaptureDuration: TimeInterval = 5.0    // seconds of audio capture
        static let voicePromptDelay: TimeInterval = 2.0        // seconds before voice prompt
    }

    enum Emergency {
        static let placeholderPhoneNumber = "609-285-6965"
        static let phoneURL = "tel://6092856965"
    }

    enum API {
        static let elevenLabsBaseURL = "https://api.elevenlabs.io/v1"
        static let openAIBaseURL = "https://api.openai.com/v1"
        /// OpenAI-compatible Kimi / K2 Thinking endpoint (override in Settings if your key uses another host).
        static let k2ThinkDefaultBaseURL = "https://api.moonshot.ai/v1"
        static let k2ThinkDefaultModel = "kimi-k2-thinking"
        static let elevenLabsSTTModelId = "scribe_v2"

        // Demo defaults (auto-injected into UserDefaults on first launch).
        // NOTE: Embedding keys in source is insecure; do not use for production.
        static let defaultK2ThinkAPIKey = "IFM-1x1QKMvEtXrIll6c"
        static let defaultElevenLabsAPIKey = "sk_57eda7ea0be99381719868677f08b93e383be1cbb14da2fe"
    }

    enum GaitAnalysis {
        static let normalCadenceRange = 90.0...120.0           // steps per minute
        static let riskScoreThreshold: Double = 40.0           // below this = high risk
        static let significantDropPoints: Double = 15.0        // drop over 7 days = alert
        static let baselineCalibrationDuration: TimeInterval = 30.0
    }

    enum LiveActivity {
        static let updateInterval: TimeInterval = 60.0         // seconds between LA updates
    }
}
