import Foundation

/// Same state-machine as the iOS build. Wrist-mounted thresholds are tuned
/// in `Constants.Motion` (slightly higher than phone-in-pocket).
@MainActor
final class FallDetectionEngine {

    enum Phase {
        case idle
        case rotationSpikeDetected(timestamp: Date, peakGyro: Double)
        case impactSpikeDetected(timestamp: Date, peakAccel: Double)
        case impactDetected(timestamp: Date, peakGyro: Double, peakAccel: Double)
        case monitoringStillness(
            since: Date,
            peakGyro: Double,
            peakAccel: Double,
            requiredDuration: TimeInterval,
            interruptThreshold: Double
        )
    }

    private var phase: Phase = .idle
    private weak var state: AppState?
    private var recentSnapshots: [SensorSnapshot] = []
    private let maxRecentCount = 250

    init(state: AppState) {
        self.state = state
    }

    func processSensorData(_ snapshot: SensorSnapshot) {
        recentSnapshots.append(snapshot)
        if recentSnapshots.count > maxRecentCount {
            recentSnapshots.removeFirst(recentSnapshots.count - maxRecentCount)
        }

        switch phase {
        case .idle:
            checkInitialTrigger(snapshot)

        case .rotationSpikeDetected(let spikeTime, let peakGyro):
            let elapsed = snapshot.timestamp.timeIntervalSince(spikeTime)
            if elapsed > Constants.Motion.falsePositiveWindow {
                phase = .idle
                return
            }
            checkImpact(snapshot, peakGyro: peakGyro)

        case .impactSpikeDetected(let impactTime, let peakAccel):
            let elapsed = snapshot.timestamp.timeIntervalSince(impactTime)
            if elapsed > Constants.Motion.quickTriggerWindow {
                phase = .idle
                return
            }
            checkRotationAfterImpact(snapshot, peakAccel: peakAccel)

        case .impactDetected(_, let peakGyro, let peakAccel):
            let violent = peakAccel >= Constants.Motion.violentImpactThreshold
                || peakGyro >= Constants.Motion.violentGyroThreshold
            let required = violent ? Constants.Motion.shortStillnessDuration : Constants.Motion.stillnessDuration
            let interrupt = violent
                ? Constants.Motion.violentStillnessInterruptThreshold
                : Constants.Motion.stillnessInterruptThreshold
            phase = .monitoringStillness(
                since: snapshot.timestamp,
                peakGyro: peakGyro,
                peakAccel: peakAccel,
                requiredDuration: required,
                interruptThreshold: interrupt
            )

        case .monitoringStillness(let since, let peakGyro, let peakAccel, let requiredDuration, let interruptThreshold):
            let elapsed = snapshot.timestamp.timeIntervalSince(since)

            if snapshot.accelerationMagnitude > interruptThreshold {
                phase = .idle
                return
            }

            if elapsed >= requiredDuration {
                triggerFallDetection(
                    peakGyro: peakGyro,
                    peakAccel: peakAccel,
                    stillnessDuration: elapsed
                )
                phase = .idle
            }
        }
    }

    private func checkInitialTrigger(_ snapshot: SensorSnapshot) {
        if snapshot.rotationMagnitude > Constants.Motion.gyroRotationThreshold {
            phase = .rotationSpikeDetected(
                timestamp: snapshot.timestamp,
                peakGyro: snapshot.rotationMagnitude
            )
            return
        }

        if snapshot.accelerationMagnitude > Constants.Motion.quickTriggerImpactThreshold {
            phase = .impactSpikeDetected(
                timestamp: snapshot.timestamp,
                peakAccel: snapshot.accelerationMagnitude
            )
        }
    }

    private func checkImpact(_ snapshot: SensorSnapshot, peakGyro: Double) {
        if snapshot.accelerationMagnitude > Constants.Motion.impactAccelThreshold {
            phase = .impactDetected(
                timestamp: snapshot.timestamp,
                peakGyro: peakGyro,
                peakAccel: snapshot.accelerationMagnitude
            )
        }
    }

    private func checkRotationAfterImpact(_ snapshot: SensorSnapshot, peakAccel: Double) {
        guard snapshot.rotationMagnitude > Constants.Motion.gyroRotationThreshold else { return }
        phase = .impactDetected(
            timestamp: snapshot.timestamp,
            peakGyro: snapshot.rotationMagnitude,
            peakAccel: peakAccel
        )
    }

    private func triggerFallDetection(peakGyro: Double, peakAccel: Double, stillnessDuration: Double) {
        guard let state else { return }

        let severity: FallSeverity
        if peakAccel > 4.0 { severity = .critical }
        else if peakAccel > 3.0 { severity = .high }
        else if peakAccel > 2.0 { severity = .medium }
        else { severity = .low }

        var event = FallEvent(
            severity: severity,
            peakGyro: peakGyro,
            peakAcceleration: peakAccel,
            stillnessDuration: stillnessDuration
        )

        event.triggers = [
            FallTrigger(description: "Rotation spike", value: "\(peakGyro.oneDecimal) rad/s", icon: "gyroscope"),
            FallTrigger(description: "Impact accel.",  value: "\(peakAccel.oneDecimal) g",   icon: "arrow.down.to.line"),
            FallTrigger(description: "Stillness",      value: "\(Int(stillnessDuration)) s",  icon: "figure.fall")
        ]
        event.timelineEntries = [
            TimelineEntry(event: "Fall detected", detail: "Gyro \(peakGyro.oneDecimal) rad/s"),
            TimelineEntry(event: "Impact",        detail: "\(peakAccel.oneDecimal) g"),
            TimelineEntry(event: "Stillness",     detail: "No motion for \(Int(stillnessDuration))s"),
            TimelineEntry(event: "Alert",         detail: "Verifying with wearer")
        ]

        state.activeFallEvent = event
        state.showFallAlert = true
        HapticsService.fallAlert()
    }
}
