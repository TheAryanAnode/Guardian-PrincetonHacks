import Foundation

/// Structured output from K2 / Kimi “thinking” pass on a spoken crisis check-in.
struct CrisisVoiceAssessment: Codable, Equatable {
    enum Intent: String, Codable {
        case help_needed
        case all_clear
        case uncertain
    }

    var intent: Intent
    var confidence: Double
    var caregiverBrief: String
    var spokenGuidance: String
    var reasoningSummary: String
}
