import Foundation

struct EmergencyContact: Identifiable, Codable {
    let id: UUID
    var name: String
    var phoneNumber: String
    var relationship: String

    init(name: String = "", phoneNumber: String = "", relationship: String = "") {
        self.id = UUID()
        self.name = name
        self.phoneNumber = phoneNumber
        self.relationship = relationship
    }
}

struct UserProfile: Codable {
    var name: String
    var age: Int
    var medicalConditions: [String]
    var medications: [String]
    var emergencyContacts: [EmergencyContact]
    var hasCompletedOnboarding: Bool
    var baselineGaitScore: Double?
    /// Personalized calibration: cadence, accel variance, tilt vs gravity.
    var gaitBaseline: GaitBaseline?

    init() {
        self.name = ""
        self.age = 0
        self.medicalConditions = []
        self.medications = []
        self.emergencyContacts = []
        self.hasCompletedOnboarding = false
        self.gaitBaseline = nil
    }

    var medicalSummary: String {
        var parts: [String] = []
        if !medicalConditions.isEmpty {
            parts.append("Conditions: \(medicalConditions.joined(separator: ", "))")
        }
        if !medications.isEmpty {
            parts.append("Medications: \(medications.joined(separator: ", "))")
        }
        return parts.isEmpty ? "No medical information on file" : parts.joined(separator: ". ")
    }
}
