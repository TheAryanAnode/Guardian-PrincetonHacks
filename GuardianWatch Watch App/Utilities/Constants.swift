import Foundation

nonisolated(unsafe)
enum Constants {

    /// Master flag for hackathon / stage demos.
    /// - Lower fall thresholds so a casual wrist shake triggers an alert.
    /// - Shorter countdown so the auto-dispatch flow is visible.
    /// - `EmergencyDispatchService` will *log* the call instead of actually
    ///   opening `tel://` so we don't dial a real number on stage.
    enum Demo {
        static let isEnabled: Bool = true
        static let suppressRealPhoneCalls: Bool = true
    }

    enum Motion {
        /// 50 Hz on the wrist is plenty and saves battery vs the 100 Hz iPhone build.
        static let updateInterval: TimeInterval = 1.0 / 50.0

        // Production thresholds (used when Demo.isEnabled == false).
        private static let prodGyro: Double = 2.4
        private static let prodImpact: Double = 2.0
        private static let prodStillness: TimeInterval = 5.0

        // Demo-friendly thresholds: an enthusiastic wrist shake is enough.
        private static let demoGyro: Double = 1.2
        private static let demoImpact: Double = 1.0
        private static let demoStillness: TimeInterval = 1.5

        static var gyroRotationThreshold: Double {
            Demo.isEnabled ? demoGyro : prodGyro
        }
        static var impactAccelThreshold: Double {
            Demo.isEnabled ? demoImpact : prodImpact
        }
        static var stillnessDuration: TimeInterval {
            Demo.isEnabled ? demoStillness : prodStillness
        }

        static let stillnessThreshold: Double = 0.2
        static let falsePositiveWindow: TimeInterval = 1.2
        static let quickTriggerImpactThreshold: Double = Demo.isEnabled ? 1.2 : 2.4
        static let quickTriggerWindow: TimeInterval = 0.75
        static let violentImpactThreshold: Double = 2.7
        static let violentGyroThreshold: Double = 3.8
        static let shortStillnessDuration: TimeInterval = 1.0
        static let stillnessInterruptThreshold: Double = 0.85
        static let violentStillnessInterruptThreshold: Double = 2.05
    }

    enum Alert {
        /// Shorter countdown during demos so the dispatch flow shows on stage.
        static var countdownDuration: Int { Demo.isEnabled ? 10 : 30 }
        static let voicePromptDelay: TimeInterval = 1.5
    }

    enum Emergency {
        /// Watch can place phone calls when paired with a phone or via cellular Apple Watch.
        static let placeholderPhoneNumber = "609-285-6965"
        static let phoneURL = "tel://6092856965"
        static let smsURLBase = "sms:"
    }

    enum API {
        static let elevenLabsBaseURL = "https://api.elevenlabs.io/v1"
        static let openAIBaseURL = "https://api.openai.com/v1"
    }

    enum GaitAnalysis {
        static let normalCadenceRange = 90.0...120.0
        static let riskScoreThreshold: Double = 40.0
        /// 10s in demo mode so onboarding finishes on stage; 30s in production.
        static var baselineCalibrationDuration: TimeInterval {
            Demo.isEnabled ? 10.0 : 30.0
        }
    }

    enum Workout {
        /// HKWorkoutSession activity type used to keep the app foregrounded
        /// for continuous fall monitoring on the wrist.
        static let activityName = "Guardian Fall Monitoring"
    }
}
