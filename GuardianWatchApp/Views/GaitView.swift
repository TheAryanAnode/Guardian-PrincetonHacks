import SwiftUI

/// Live gait insights + recalibration. Replaces the iOS GaitLiveInsightCard +
/// GaitTrendView. Big numbers, small chips, no Charts framework needed.
struct GaitView: View {
    @Bindable var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                scoreCircle

                if !state.liveGaitInsight.hintLines.isEmpty {
                    WatchCard {
                        Text("INSIGHTS")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(Theme.textMuted)
                        ForEach(state.liveGaitInsight.hintLines, id: \.self) { hint in
                            Label(hint, systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.ledYellow)
                        }
                    }
                }

                WatchCard {
                    Text("POSTURE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.textMuted)
                    Text(state.liveGaitInsight.postureSummary)
                        .font(.system(size: 14, weight: .semibold))
                    Text("Confidence: \(state.liveGaitInsight.confidence.rawValue)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textMuted)
                }

                Button {
                    HapticsService.tick()
                    Task { await state.recalibrateGaitBaseline(duration: 30) }
                } label: {
                    Label(
                        state.isRecalibratingGait ? "Calibrating…" : "Calibrate (30s walk)",
                        systemImage: "figure.walk.motion"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(state.isRecalibratingGait)
            }
            .padding(.horizontal, 6)
        }
        .containerBackground(Theme.background.gradient, for: .tabView)
        .navigationTitle("Gait")
    }

    private var scoreCircle: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Theme.surfaceHi, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: CGFloat(min(state.currentGaitScore / 100.0, 1.0)))
                    .stroke(
                        Theme.riskColor(state.gaitRiskLevel),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int(state.currentGaitScore))")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                    Text(state.gaitStatusText)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(Theme.textMuted)
                }
            }
            .frame(width: 110, height: 110)
            .frame(maxWidth: .infinity)
        }
    }
}
