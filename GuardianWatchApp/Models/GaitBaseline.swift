import Foundation

/// Baseline captured during a calibration walk on the wrist.
struct GaitBaseline: Codable, Equatable {
    var avgCadence: Double
    var avgAccelVariance: Double
    var avgForwardTiltDegrees: Double
    var sampleCount: Int
    var recordedAt: Date
    var compositeGaitScore: Double

    init(
        avgCadence: Double = 0,
        avgAccelVariance: Double = 0,
        avgForwardTiltDegrees: Double = 0,
        sampleCount: Int = 0,
        recordedAt: Date = .now,
        compositeGaitScore: Double = 0
    ) {
        self.avgCadence = avgCadence
        self.avgAccelVariance = avgAccelVariance
        self.avgForwardTiltDegrees = avgForwardTiltDegrees
        self.sampleCount = sampleCount
        self.recordedAt = recordedAt
        self.compositeGaitScore = compositeGaitScore
    }

    enum CodingKeys: String, CodingKey {
        case avgCadence, avgAccelVariance, avgForwardTiltDegrees, sampleCount, recordedAt, compositeGaitScore
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        avgCadence = try c.decodeIfPresent(Double.self, forKey: .avgCadence) ?? 0
        avgAccelVariance = try c.decodeIfPresent(Double.self, forKey: .avgAccelVariance) ?? 0
        avgForwardTiltDegrees = try c.decodeIfPresent(Double.self, forKey: .avgForwardTiltDegrees) ?? 0
        sampleCount = try c.decodeIfPresent(Int.self, forKey: .sampleCount) ?? 0
        recordedAt = try c.decodeIfPresent(Date.self, forKey: .recordedAt) ?? .now
        compositeGaitScore = try c.decodeIfPresent(Double.self, forKey: .compositeGaitScore) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(avgCadence, forKey: .avgCadence)
        try c.encode(avgAccelVariance, forKey: .avgAccelVariance)
        try c.encode(avgForwardTiltDegrees, forKey: .avgForwardTiltDegrees)
        try c.encode(sampleCount, forKey: .sampleCount)
        try c.encode(recordedAt, forKey: .recordedAt)
        try c.encode(compositeGaitScore, forKey: .compositeGaitScore)
    }
}

enum GaitConfidence: String, Codable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
}

struct GaitLiveInsight: Equatable {
    var gaitScore: Double
    var postureSummary: String
    var confidence: GaitConfidence
    var qualityDropPercent: Double?
    var heavySteps: Bool
    var unevenGait: Bool
    var forwardLean: Bool
    var hintLines: [String]

    var gaitRiskLevel: GaitRiskLevel {
        if gaitScore >= 70 { return .low }
        if gaitScore >= 50 { return .moderate }
        return .high
    }

    static let empty = GaitLiveInsight(
        gaitScore: 0,
        postureSummary: "—",
        confidence: .low,
        qualityDropPercent: nil,
        heavySteps: false,
        unevenGait: false,
        forwardLean: false,
        hintLines: []
    )
}
