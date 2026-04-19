import SwiftUI

/// Primary "are you protected right now?" screen. One screen-tap toggles
/// monitoring, big legible type, traffic-light at the top.
struct DashboardView: View {
    @Bindable var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                statusHeader

                Button {
                    HapticsService.tick()
                    Task { await toggleMonitoring() }
                } label: {
                    HStack {
                        Image(systemName: state.isMonitoring ? "stop.fill" : "play.fill")
                        Text(state.isMonitoring ? "Stop Monitoring" : "Start Monitoring")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(state.isMonitoring ? Color.gray : Theme.accent)

                liveStats

                if Constants.Demo.isEnabled {
                    Button {
                        HapticsService.tick()
                        simulateFall()
                    } label: {
                        Label("Simulate Fall", systemImage: "bolt.fill")
                            .frame(maxWidth: .infinity)
                            .font(.system(size: 14, weight: .bold))
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.ledYellow)
                }

                if let snapshot = state.currentSensorData {
                    WatchCard {
                        Text("LIVE SENSORS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.textMuted)
                        sensorRow(label: "Gyro",  value: snapshot.rotationMagnitude,    unit: "rad/s")
                        sensorRow(label: "Accel", value: snapshot.accelerationMagnitude, unit: "g")
                        sensorRow(label: "Tilt",  value: snapshot.forwardTiltDegrees,   unit: "°")
                    }
                }
            }
            .padding(.horizontal, 6)
        }
        .containerBackground(Theme.background.gradient, for: .tabView)
        .navigationTitle("Guardian")
    }

    private var statusHeader: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(state.isMonitoring ? Theme.ledGreen : Theme.textMuted)
                .frame(width: 10, height: 10)
                .shadow(color: state.isMonitoring ? Theme.ledGreen.opacity(0.6) : .clear, radius: 4)
            Text(state.isMonitoring ? "Protected" : "Inactive")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(state.isMonitoring ? Theme.ledGreen : Theme.textMuted)
            Spacer()
        }
    }

    private var liveStats: some View {
        HStack(spacing: 6) {
            statCard(
                value: "\(Int(state.currentGaitScore))",
                label: "GAIT",
                color: Theme.riskColor(state.gaitRiskLevel)
            )
            statCard(
                value: "\(state.fallHistory.count)",
                label: "FALLS",
                color: state.fallHistory.isEmpty ? Theme.ledGreen : Theme.ledYellow
            )
        }
    }

    private func statCard(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, minHeight: 50)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius))
    }

    private func sensorRow(label: String, value: Double, unit: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.textMuted)
            Spacer()
            Text("\(value.oneDecimal) \(unit)")
                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                .foregroundStyle(Theme.textPrimary)
        }
    }

    /// Demo helper: fabricate a plausible fall event so we can show the
    /// alert flow in the simulator (which can't generate real motion).
    private func simulateFall() {
        var event = FallEvent(
            severity: .high,
            peakGyro: 3.1,
            peakAcceleration: 2.7,
            stillnessDuration: 5
        )
        event.triggers = [
            FallTrigger(description: "Rotation spike", value: "3.1 rad/s", icon: "gyroscope"),
            FallTrigger(description: "Impact accel.",  value: "2.7 g",     icon: "arrow.down.to.line"),
            FallTrigger(description: "Stillness",      value: "5 s",       icon: "figure.fall")
        ]
        event.timelineEntries = [
            TimelineEntry(event: "Fall detected", detail: "Simulated for demo"),
            TimelineEntry(event: "Impact",        detail: "2.7 g"),
            TimelineEntry(event: "Stillness",     detail: "No motion for 5s"),
            TimelineEntry(event: "Alert",         detail: "Verifying with wearer")
        ]
        state.activeFallEvent = event
        state.showFallAlert = true
        HapticsService.fallAlert()
    }

    private func toggleMonitoring() async {
        if state.isMonitoring {
            await MotionService.shared.stopMonitoring()
        } else {
            // Make sure HealthKit auth is in hand before starting the workout session.
            _ = await WorkoutSessionManager.shared.requestAuthorization()
            await MotionService.shared.startMonitoring(state: state)
        }
    }
}
