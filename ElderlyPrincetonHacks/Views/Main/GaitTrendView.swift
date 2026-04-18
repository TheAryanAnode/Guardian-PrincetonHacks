import SwiftUI
import Charts

struct GaitTrendView: View {
    var state: AppState

    private var displayData: [GaitRecord] {
        if state.gaitHistory.isEmpty {
            return sampleData
        }
        return Array(state.gaitHistory.prefix(7).reversed())
    }

    var body: some View {
        NeuCard(showScrews: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("GAIT ANALYSIS")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(Theme.textMuted)

                        Text("7-Day Trend")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(Theme.textPrimary)
                    }

                    Spacer()

                    LEDIndicator(
                        status: state.gaitRiskLevel.ledStatus,
                        size: 8
                    )
                }

                Chart(displayData) { record in
                    LineMark(
                        x: .value("Date", record.date, unit: .day),
                        y: .value("Score", record.overallScore)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.accent, Theme.accent.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2.5))

                    AreaMark(
                        x: .value("Date", record.date, unit: .day),
                        y: .value("Score", record.overallScore)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.accent.opacity(0.15), Theme.accent.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    PointMark(
                        x: .value("Date", record.date, unit: .day),
                        y: .value("Score", record.overallScore)
                    )
                    .foregroundStyle(Theme.accent)
                    .symbolSize(20)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                        AxisValueLabel {
                            Text("\(value.as(Int.self) ?? 0)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(Theme.textMuted)
                        }
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Theme.borderDark.opacity(0.3))
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(Theme.textMuted)
                    }
                }
                .frame(height: 150)

                HStack(spacing: 16) {
                    gaitMetric(label: "CADENCE", value: "\(Int(displayData.last?.cadence ?? 0))", unit: "spm")
                    gaitMetric(label: "SYMMETRY", value: "\(Int(displayData.last?.symmetry ?? 0))%", unit: "")
                    gaitMetric(label: "SMOOTH", value: "\(Int(displayData.last?.smoothness ?? 0))%", unit: "")
                    gaitMetric(label: "SCORE", value: "\(Int(state.currentGaitScore))", unit: "/100")
                }
            }
        }
    }

    private func gaitMetric(label: String, value: String, unit: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(1)
                .foregroundColor(Theme.textMuted)

            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Theme.textMuted)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var sampleData: [GaitRecord] {
        (0..<7).map { dayOffset in
            let date = Calendar.current.date(byAdding: .day, value: -6 + dayOffset, to: .now)!
            let baseScore = 72.0
            let variation = Double.random(in: -8...8)
            return GaitRecord(
                date: date,
                cadence: 105 + Double.random(in: -10...10),
                strideRegularity: 78 + Double.random(in: -5...5),
                symmetry: 82 + Double.random(in: -5...5),
                smoothness: 70 + Double.random(in: -8...8)
            )
        }
    }
}
