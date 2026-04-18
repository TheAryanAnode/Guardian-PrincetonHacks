import Foundation

@MainActor
final class GaitAnalysisService {
    static let shared = GaitAnalysisService()

    private var analysisBuffer: [SensorSnapshot] = []
    private var calibrationBuffer: [SensorSnapshot] = []
    private let bufferSize = 3000

    private(set) var isCalibratingWalk = false

    private init() {}

    func beginCalibrationWalk() {
        isCalibratingWalk = true
        calibrationBuffer.removeAll()
    }

    func cancelCalibrationWalk() {
        isCalibratingWalk = false
        calibrationBuffer.removeAll()
    }

    func addSample(_ snapshot: SensorSnapshot) {
        analysisBuffer.append(snapshot)
        if analysisBuffer.count > bufferSize {
            analysisBuffer.removeFirst(analysisBuffer.count - bufferSize)
        }
        if isCalibratingWalk {
            calibrationBuffer.append(snapshot)
            if calibrationBuffer.count > 9000 {
                calibrationBuffer.removeFirst(calibrationBuffer.count - 9000)
            }
        }
    }

    /// End walking calibration and produce baseline + a snapshot `GaitRecord` for history charts.
    func finalizeCalibrationWalk() -> (baseline: GaitBaseline, record: GaitRecord)? {
        isCalibratingWalk = false
        let data = calibrationBuffer
        calibrationBuffer.removeAll()
        guard data.count >= 800 else { return nil }
        return buildBaselineAndRecord(from: data)
    }

    func analyzeGait() -> GaitRecord? {
        guard analysisBuffer.count >= 500 else { return nil }
        let window = Array(analysisBuffer.suffix(bufferSize))
        return recordFromWindow(window)
    }

    /// Compare last ~12s of motion to baseline; meant for on-screen “AI” insights during monitoring.
    func computeLiveInsight(baseline: GaitBaseline?) -> GaitLiveInsight {
        guard let baseline, analysisBuffer.count > 400 else {
            return .empty
        }
        let sampleCount = min(1200, analysisBuffer.count)
        let window = Array(analysisBuffer.suffix(sampleCount))

        let cadence = estimateCadence(from: window)
        let regularity = estimateStrideRegularity(from: window)
        let meanTilt = window.map(\.forwardTiltDegrees).reduce(0, +) / Double(window.count)

        let verticalPeaks = estimateVerticalImpactPeaks(from: window)
        let strideCV = estimateStrideIntervalCV(from: window)

        let record = GaitRecord(
            cadence: cadence,
            strideRegularity: regularity,
            symmetry: estimateSymmetry(from: window),
            smoothness: estimateSmoothness(from: window)
        )
        let currentScore = record.overallScore

        let tiltDelta = abs(meanTilt - baseline.avgForwardTiltDegrees)

        let heavySteps = verticalPeaks > max(2.2, baseline.avgAccelVariance * 6.0)
            || maxVerticalAccel(from: window) > 3.2

        let unevenGait = strideCV > 0.22 && strideCV > baselineStrideCVHint(baseline) + 0.08

        let forwardLean = meanTilt > baseline.avgForwardTiltDegrees + 12

        var hints: [String] = []
        if heavySteps { hints.append("You're stomping more than usual") }
        if unevenGait { hints.append("Your gait looks uneven") }
        if forwardLean { hints.append("You may be slouching") }

        let qualityDrop = max(0, baseline.compositeGaitScore - currentScore)
        let qualityDropPercent = baseline.compositeGaitScore > 0
            ? (qualityDrop / baseline.compositeGaitScore) * 100
            : nil

        let postureSummary: String
        if forwardLean {
            postureSummary = "Slight forward lean detected"
        } else if tiltDelta < 8 {
            postureSummary = "Neutral vs baseline"
        } else {
            postureSummary = "Posture shifted vs baseline"
        }

        let confidence: GaitConfidence
        if window.count >= 900 { confidence = .high }
        else if window.count >= 450 { confidence = .medium }
        else { confidence = .low }

        return GaitLiveInsight(
            gaitScore: min(max(currentScore, 0), 100),
            postureSummary: postureSummary,
            confidence: confidence,
            qualityDropPercent: qualityDropPercent.map { min($0, 100) },
            heavySteps: heavySteps,
            unevenGait: unevenGait,
            forwardLean: forwardLean,
            hintLines: hints
        )
    }

    // MARK: - Baseline

    private func buildBaselineAndRecord(from data: [SensorSnapshot]) -> (GaitBaseline, GaitRecord)? {
        let cadence = estimateCadence(from: data)
        let variance = estimateAccelVariance(from: data)
        let meanTilt = data.map(\.forwardTiltDegrees).reduce(0, +) / Double(data.count)
        let record = recordFromWindow(data)
        let baseline = GaitBaseline(
            avgCadence: cadence,
            avgAccelVariance: variance,
            avgForwardTiltDegrees: meanTilt,
            sampleCount: data.count,
            recordedAt: .now,
            compositeGaitScore: record.overallScore
        )
        return (baseline, record)
    }

    private func baselineStrideCVHint(_ baseline: GaitBaseline) -> Double {
        let regularity = baseline.strideRegularityHint
        return max(0.08, (100 - regularity) / 500)
    }

    private func recordFromWindow(_ data: [SensorSnapshot]) -> GaitRecord {
        GaitRecord(
            cadence: estimateCadence(from: data),
            strideRegularity: estimateStrideRegularity(from: data),
            symmetry: estimateSymmetry(from: data),
            smoothness: estimateSmoothness(from: data)
        )
    }

    private func estimateAccelVariance(from data: [SensorSnapshot]) -> Double {
        let mags = data.map(\.accelerationMagnitude)
        guard !mags.isEmpty else { return 0 }
        let mean = mags.reduce(0, +) / Double(mags.count)
        let v = mags.map { pow($0 - mean, 2) }.reduce(0, +) / Double(mags.count)
        return v
    }

    private func estimateVerticalImpactPeaks(from data: [SensorSnapshot]) -> Double {
        let y = data.map { abs($0.accelerationY) }
        return y.max() ?? 0
    }

    private func maxVerticalAccel(from data: [SensorSnapshot]) -> Double {
        data.map { abs($0.accelerationY) }.max() ?? 0
    }

    /// Coefficient of variation of step intervals (0–1 scale approx).
    private func estimateStrideIntervalCV(from data: [SensorSnapshot]) -> Double {
        let verticalAccel = data.map { $0.accelerationY }
        let mean = verticalAccel.reduce(0, +) / Double(verticalAccel.count)

        var peakIndices: [Int] = []
        for i in 2..<(verticalAccel.count - 2) {
            let val = verticalAccel[i] - mean
            if val > 0.08,
               val > verticalAccel[i - 1] - mean,
               val > verticalAccel[i - 2] - mean,
               val > verticalAccel[i + 1] - mean,
               val > verticalAccel[i + 2] - mean {
                peakIndices.append(i)
            }
        }
        guard peakIndices.count >= 3 else { return 0.15 }

        var intervals: [Int] = []
        for i in 1..<peakIndices.count {
            intervals.append(peakIndices[i] - peakIndices[i - 1])
        }
        let meanInterval = Double(intervals.reduce(0, +)) / Double(intervals.count)
        let variance = intervals.map { pow(Double($0) - meanInterval, 2) }.reduce(0, +) / Double(intervals.count)
        let cv = (variance.squareRoot() / max(meanInterval, 1))
        return min(cv, 1.0)
    }

    // MARK: - Heuristic Algorithms (deviceMotion userAcceleration)

    private func estimateCadence(from data: [SensorSnapshot]) -> Double {
        let verticalAccel = data.map { $0.accelerationY }
        let mean = verticalAccel.reduce(0, +) / Double(verticalAccel.count)

        var crossings = 0
        for i in 1..<verticalAccel.count {
            let prev = verticalAccel[i - 1] - mean
            let curr = verticalAccel[i] - mean
            if prev * curr < 0 { crossings += 1 }
        }

        let durationSeconds = Double(data.count) * Constants.Motion.updateInterval
        let stepsPerSecond = Double(crossings) / (2.0 * durationSeconds)
        let stepsPerMinute = stepsPerSecond * 60.0

        return min(max(stepsPerMinute, 0), 200)
    }

    private func estimateStrideRegularity(from data: [SensorSnapshot]) -> Double {
        let verticalAccel = data.map { $0.accelerationY }
        let mean = verticalAccel.reduce(0, +) / Double(verticalAccel.count)

        var peakIndices: [Int] = []
        for i in 2..<(verticalAccel.count - 2) {
            let val = verticalAccel[i] - mean
            if val > 0.1,
               val > verticalAccel[i - 1] - mean,
               val > verticalAccel[i - 2] - mean,
               val > verticalAccel[i + 1] - mean,
               val > verticalAccel[i + 2] - mean {
                peakIndices.append(i)
            }
        }

        guard peakIndices.count >= 3 else { return 50.0 }

        var intervals: [Int] = []
        for i in 1..<peakIndices.count {
            intervals.append(peakIndices[i] - peakIndices[i - 1])
        }

        let meanInterval = Double(intervals.reduce(0, +)) / Double(intervals.count)
        let variance = intervals.map { pow(Double($0) - meanInterval, 2) }.reduce(0, +) / Double(intervals.count)
        let cv = (variance.squareRoot() / meanInterval) * 100

        return max(100 - cv * 5, 0)
    }

    private func estimateSymmetry(from data: [SensorSnapshot]) -> Double {
        let lateralAccel = data.map { $0.accelerationX }

        let positive = lateralAccel.filter { $0 > 0 }.reduce(0, +)
        let negative = abs(lateralAccel.filter { $0 < 0 }.reduce(0, +))

        guard positive > 0 && negative > 0 else { return 50.0 }

        let ratio = min(positive, negative) / max(positive, negative)
        return ratio * 100
    }

    private func estimateSmoothness(from data: [SensorSnapshot]) -> Double {
        guard data.count >= 3 else { return 50.0 }

        var jerkValues: [Double] = []
        let dt = Constants.Motion.updateInterval

        for i in 1..<data.count {
            let jerkX = (data[i].accelerationX - data[i - 1].accelerationX) / dt
            let jerkY = (data[i].accelerationY - data[i - 1].accelerationY) / dt
            let jerkZ = (data[i].accelerationZ - data[i - 1].accelerationZ) / dt
            let magnitude = (jerkX * jerkX + jerkY * jerkY + jerkZ * jerkZ).squareRoot()
            jerkValues.append(magnitude)
        }

        let meanJerk = jerkValues.reduce(0, +) / Double(jerkValues.count)

        let score = max(100 - (meanJerk * 0.5), 0)
        return min(score, 100)
    }
}

private extension GaitBaseline {
    /// Persisted hint for uneven-gait thresholding when we don’t store full stride history.
    var strideRegularityHint: Double {
        min(max(avgCadence * 0.35, 40), 85)
    }
}
