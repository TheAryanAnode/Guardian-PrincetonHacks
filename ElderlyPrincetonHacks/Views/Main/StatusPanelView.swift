import SwiftUI

struct StatusPanelView: View {
    var state: AppState

    var body: some View {
        NeuCard(showScrews: true, showVents: true) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("SYSTEM STATUS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(Theme.textMuted)

                    Spacer()

                    LEDIndicator(
                        status: state.isMonitoring ? .active : .offline,
                        size: 8
                    )
                }

                HStack(spacing: 20) {
                    sensorGauge(
                        label: "GYRO",
                        value: state.currentSensorData?.rotationMagnitude ?? 0,
                        unit: "rad/s",
                        maxValue: 5.0
                    )

                    sensorGauge(
                        label: "ACCEL",
                        value: state.currentSensorData?.accelerationMagnitude ?? 1.0,
                        unit: "g",
                        maxValue: 4.0
                    )

                    sensorGauge(
                        label: "GAIT",
                        value: state.currentGaitScore,
                        unit: "pts",
                        maxValue: 100.0
                    )
                }

                if let snapshot = state.currentSensorData {
                    HStack {
                        Text("LAST UPDATE: \(snapshot.timestamp.shortTimestamp)")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(Theme.textMuted.opacity(0.7))
                        Spacer()
                        Text("100 Hz")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textMuted.opacity(0.7))
                    }
                }
            }
        }
    }

    private func sensorGauge(label: String, value: Double, unit: String, maxValue: Double) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Theme.recessed, lineWidth: 6)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: min(value / maxValue, 1.0))
                    .stroke(
                        gaugeColor(value: value, max: maxValue),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text(value.oneDecimal)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.textPrimary)
                    Text(unit)
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                }
            }

            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(1.5)
                .foregroundColor(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func gaugeColor(value: Double, max: Double) -> Color {
        let ratio = value / max
        if ratio > 0.8 { return Theme.ledRed }
        if ratio > 0.5 { return Theme.ledYellow }
        return Theme.ledGreen
    }
}
