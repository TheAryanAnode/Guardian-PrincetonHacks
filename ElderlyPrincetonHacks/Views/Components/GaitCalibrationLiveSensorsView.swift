import SwiftUI

/// Live gyro / user-acceleration magnitudes while walking calibration (100 Hz stream → downsampled draw).
struct GaitCalibrationLiveSensorsView: View {
    @Bindable var state: AppState

    private var recent: [SensorSnapshot] {
        Array(state.sensorHistory.suffix(220))
    }

    var body: some View {
        NeuCard(showScrews: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("LIVE SENSOR TELEMETRY")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(Theme.textMuted)

                Text("Rotation magnitude (rad/s) and user acceleration (g) — walk naturally so peaks reflect your stride.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.textMuted)

                SensorWaveformCanvas(samples: recent)
                    .frame(height: 112)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd))

                HStack(spacing: 12) {
                    liveChip(
                        label: "GYRO |ω|",
                        value: state.currentSensorData?.rotationMagnitude ?? 0,
                        suffix: " rad/s"
                    )
                    liveChip(
                        label: "ACCEL |a|",
                        value: state.currentSensorData?.accelerationMagnitude ?? 0,
                        suffix: " g"
                    )
                }
            }
        }
    }

    private func liveChip(label: String, value: Double, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.textMuted)
            Text(String(format: "%.2f", value) + suffix)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Theme.recessed.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMd))
    }
}

private struct SensorWaveformCanvas: View {
    let samples: [SensorSnapshot]

    var body: some View {
        Canvas { context, size in
            guard samples.count > 3 else {
                let rect = CGRect(origin: .zero, size: size)
                context.fill(Path(roundedRect: rect, cornerRadius: 8), with: .color(Theme.recessed))
                return
            }

            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(roundedRect: rect, cornerRadius: 8), with: .color(Theme.recessed.opacity(0.9)))

            let gyros = samples.map(\.rotationMagnitude)
            let accels = samples.map(\.accelerationMagnitude)
            let maxG = max(gyros.max() ?? 0.2, 0.2)
            let maxA = max(accels.max() ?? 0.2, 0.2)

            let midY = size.height * 0.48

            var gyroPath = Path()
            var accelPath = Path()

            for i in samples.indices {
                let t = CGFloat(i) / CGFloat(samples.count - 1)
                let x = t * size.width
                let yG = midY - CGFloat(gyros[i] / maxG) * (size.height * 0.38)
                let yA = midY + CGFloat(accels[i] / maxA) * (size.height * 0.38)
                let pG = CGPoint(x: x, y: yG)
                let pA = CGPoint(x: x, y: yA)
                if i == samples.startIndex {
                    gyroPath.move(to: pG)
                    accelPath.move(to: pA)
                } else {
                    gyroPath.addLine(to: pG)
                    accelPath.addLine(to: pA)
                }
            }

            context.stroke(gyroPath, with: .color(Theme.accent), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            context.stroke(accelPath, with: .color(Theme.darkSlate), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

            context.stroke(
                Path { p in
                    p.move(to: CGPoint(x: 0, y: midY))
                    p.addLine(to: CGPoint(x: size.width, y: midY))
                },
                with: .color(Theme.borderDark.opacity(0.35)),
                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
            )
        }
        .accessibilityLabel("Live gyroscope and acceleration chart")
    }
}
