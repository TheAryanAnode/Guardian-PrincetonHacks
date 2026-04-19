import Foundation

struct GaitRecord: Identifiable, Codable {
    let id: UUID
    let date: Date
    var cadence: Double
    var strideRegularity: Double
    var symmetry: Double
    var smoothness: Double
    var overallScore: Double

    var riskLevel: GaitRiskLevel {
        if overallScore >= 70 { return .low }
        if overallScore >= 50 { return .moderate }
        return .high
    }

    init(
        date: Date = .now,
        cadence: Double = 0,
        strideRegularity: Double = 0,
        symmetry: Double = 0,
        smoothness: Double = 0
    ) {
        self.id = UUID()
        self.date = date
        self.cadence = cadence
        self.strideRegularity = strideRegularity
        self.symmetry = symmetry
        self.smoothness = smoothness
        self.overallScore = (min(max(cadence, 0), 100) * 0.3)
            + (strideRegularity * 0.25)
            + (symmetry * 0.25)
            + (smoothness * 0.2)
    }
}

enum GaitRiskLevel: String, Codable {
    case low = "Low Risk"
    case moderate = "Moderate Risk"
    case high = "High Risk"
}
