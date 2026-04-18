import Foundation

nonisolated(unsafe)
enum Constants {

    enum Motion {
        static let updateInterval: TimeInterval = 1.0 / 100.0 // 100Hz
        static let gyroRotationThreshold: Double = 2.2         // rad/s
        static let impactAccelThreshold: Double = 1.9          // g-force
        static let stillnessThreshold: Double = 0.2            // g-force variance
        static let stillnessDuration: TimeInterval = 6.0       // seconds
        static let falsePositiveWindow: TimeInterval = 0.9     // seconds between rotation + impact
        static let gaitWindowDuration: TimeInterval = 30.0     // seconds of data for gait analysis
        static let quickTriggerImpactThreshold: Double = 2.3   // g-force, impact-first path
        static let quickTriggerWindow: TimeInterval = 0.75     // seconds to look for rotation around impact
        /// High-energy events (shake / slam) use shorter “settle” time so the alert can fire after you stop moving.
        static let violentImpactThreshold: Double = 2.55
        static let violentGyroThreshold: Double = 3.8
        static let shortStillnessDuration: TimeInterval = 1.35
        /// While waiting for stillness: movement above this (user accel, g) cancels and restarts detection.
        static let stillnessInterruptThreshold: Double = 0.85
        static let violentStillnessInterruptThreshold: Double = 2.05
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
