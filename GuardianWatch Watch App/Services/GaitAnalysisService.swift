import Foundation

/// Identical algorithms to the iOS build, but with smaller buffers because
/// the watch has tighter memory budgets.
@MainActor
final class GaitAnalysisService {
    static let shared = GaitAnalysisService()

    private var analysisBuffer: [SensorSnapshot] = []
    private var calibrationBuffer: [SensorSnapshot] = []
    private let bufferSize = 1500

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
            if calibrationBuffer.count > 4500 {
                calibrationBuffer.removeFirst(calibrationBuffer.count - 4500)
            }
        }
    }

    func finalizeCalibrationWalk() -> (baseline: GaitBaseline, record: GaitRecord)? {
        isCalibratingWalk = false
        let data = calibrationBuffer
        calibrationBuffer.removeAll()
        guard data.count >= 400 else { return nil }
        return buildBaselineAndRecord(from: data)
    }

    func analyzeGait() -> GaitRecord? {
        guard analysisBuffer.count >= 250 else { return nil }
        let window = Array(analysisBuffer.suffix(bufferSize))
        return recordFromWindow(window)
    }

    func computeLiveInsight(baseline: GaitBaseline?) -> GaitLiveInsight {
        guard let baseline, analysisBuffer.count > 200 else { return .empty }
        let sampleCount = min(600, analysisBuffer.count)
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
        if heavySteps  { hints.append("Heavy steps") }
        if unevenGait  { hints.append("Uneven gait") }
        if forwardLean { hints.append("Forward lean") }

        let qualityDrop = max(0, baseline.compositeGaitScore - currentScore)
        let qualityDropPercent = baseline.compositeGaitScore > 0
            ? min((qualityDrop / baseline.compositeGaitScore) * 100, 100)
            : nil

        let postureSummary: String
        if forwardLean { postureSummary = "Slight lean" }
        else if tiltDelta < 8 { postureSummary = "Neutral" }
        else { postureSummary = "Posture shift" }

        let confidence: GaitConfidence
        if window.count >= 450 { confidence = .high }
        else if window.count >= 250 { confidence = .medium }
        else { confidence = .low }

        return GaitLiveInsight(
            gaitScore: min(max(currentScore, 0), 100),
            postureSummary: postureSummary,
            confidence: confidence,
            qualityDropPercent: qualityDropPercent,
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
        let regularity = min(max(baseline.avgCadence * 0.35, 40), 85)
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
        return mags.map { pow($0 - mean, 2) }.reduce(0, +) / Double(mags.count)
    }

    private func estimateVerticalImpactPeaks(from data: [SensorSnapshot]) -> Double {
        data.map { abs($0.accelerationY) }.max() ?? 0
    }

    private func maxVerticalAccel(from data: [SensorSnapshot]) -> Double {
        data.map { abs($0.accelerationY) }.max() ?? 0
    }

    private func estimateStrideIntervalCV(from data: [SensorSnapshot]) -> Double {
        let v = data.map { $0.accelerationY }
        let mean = v.reduce(0, +) / Double(v.count)
        var peaks: [Int] = []
        for i in 2..<(v.count - 2) {
            let val = v[i] - mean
            if val > 0.08,
               val > v[i - 1] - mean, val > v[i - 2] - mean,
               val > v[i + 1] - mean, val > v[i + 2] - mean {
                peaks.append(i)
            }
        }
        guard peaks.count >= 3 else { return 0.15 }
        var intervals: [Int] = []
        for i in 1..<peaks.count { intervals.append(peaks[i] - peaks[i - 1]) }
        let meanI = Double(intervals.reduce(0, +)) / Double(intervals.count)
        let varI = intervals.map { pow(Double($0) - meanI, 2) }.reduce(0, +) / Double(intervals.count)
        return min(varI.squareRoot() / max(meanI, 1), 1.0)
    }

    private func estimateCadence(from data: [SensorSnapshot]) -> Double {
        let v = data.map { $0.accelerationY }
        let mean = v.reduce(0, +) / Double(v.count)
        var crossings = 0
        for i in 1..<v.count where (v[i - 1] - mean) * (v[i] - mean) < 0 {
            crossings += 1
        }
        let durationSeconds = Double(data.count) * Constants.Motion.updateInterval
        let stepsPerSecond = Double(crossings) / (2.0 * durationSeconds)
        return min(max(stepsPerSecond * 60.0, 0), 200)
    }

    private func estimateStrideRegularity(from data: [SensorSnapshot]) -> Double {
        let v = data.map { $0.accelerationY }
        let mean = v.reduce(0, +) / Double(v.count)
        var peaks: [Int] = []
        for i in 2..<(v.count - 2) {
            let val = v[i] - mean
            if val > 0.1,
               val > v[i - 1] - mean, val > v[i - 2] - mean,
               val > v[i + 1] - mean, val > v[i + 2] - mean {
                peaks.append(i)
            }
        }
        guard peaks.count >= 3 else { return 50.0 }
        var intervals: [Int] = []
        for i in 1..<peaks.count { intervals.append(peaks[i] - peaks[i - 1]) }
        let meanI = Double(intervals.reduce(0, +)) / Double(intervals.count)
        let varI = intervals.map { pow(Double($0) - meanI, 2) }.reduce(0, +) / Double(intervals.count)
        let cv = (varI.squareRoot() / meanI) * 100
        return max(100 - cv * 5, 0)
    }

    private func estimateSymmetry(from data: [SensorSnapshot]) -> Double {
        let l = data.map { $0.accelerationX }
        let positive = l.filter { $0 > 0 }.reduce(0, +)
        let negative = abs(l.filter { $0 < 0 }.reduce(0, +))
        guard positive > 0, negative > 0 else { return 50.0 }
        return min(positive, negative) / max(positive, negative) * 100
    }

    private func estimateSmoothness(from data: [SensorSnapshot]) -> Double {
        guard data.count >= 3 else { return 50.0 }
        var jerks: [Double] = []
        let dt = Constants.Motion.updateInterval
        for i in 1..<data.count {
            let jx = (data[i].accelerationX - data[i - 1].accelerationX) / dt
            let jy = (data[i].accelerationY - data[i - 1].accelerationY) / dt
            let jz = (data[i].accelerationZ - data[i - 1].accelerationZ) / dt
            jerks.append((jx * jx + jy * jy + jz * jz).squareRoot())
        }
        let meanJerk = jerks.reduce(0, +) / Double(jerks.count)
        return min(max(100 - (meanJerk * 0.5), 0), 100)
    }
}
