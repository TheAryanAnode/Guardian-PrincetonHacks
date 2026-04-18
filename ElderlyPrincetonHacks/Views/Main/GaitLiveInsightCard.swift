import SwiftUI

struct GaitLiveInsightCard: View {
    var state: AppState

    var body: some View {
        NeuCard(showScrews: true, showVents: true) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("LIVE GAIT AI")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(Theme.textMuted)
                    Spacer()
                    Text("CONFIDENCE: \(state.liveGaitInsight.confidence.rawValue.uppercased())")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(confidenceColor(state.liveGaitInsight.confidence))
                }

                if state.userProfile.gaitBaseline == nil {
                    Text("Walk for 30–60s in Settings (or finish onboarding) to capture your baseline. Then we compare live motion vs your norm.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.textMuted)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("Gait score:")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.textMuted)
                        Text("\(Int(state.liveGaitInsight.gaitScore))")
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textPrimary)
                        Text("/ 100")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textMuted)
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "figure.stand")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.accent)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Posture: \(state.liveGaitInsight.postureSummary)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)
                            if let drop = state.liveGaitInsight.qualityDropPercent, drop > 0.5 {
                                Text("Your walking quality dropped \(Int(round(drop)))% compared to baseline")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Theme.ledYellow)
                            } else if state.isMonitoring {
                                Text("Within range of your baseline walk")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Theme.ledGreen)
                            }
                        }
                    }

                    if !state.liveGaitInsight.hintLines.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(state.liveGaitInsight.hintLines, id: \.self) { line in
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "sparkles")
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.accent)
                                    Text(line)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Theme.textPrimary)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
    }

    private func confidenceColor(_ c: GaitConfidence) -> Color {
        switch c {
        case .high: return Theme.ledGreen
        case .medium: return Theme.ledYellow
        case .low: return Theme.textMuted
        }
    }
}
