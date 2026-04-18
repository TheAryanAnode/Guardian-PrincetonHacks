import ActivityKit
import SwiftUI
import WidgetKit

struct FallMonitorLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FallDetectionAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor(context.state.status))
                            .frame(width: 8, height: 8)
                        Text(statusTitle(context.state.status))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("GAIT: \(context.state.gaitScore)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.alertActive, let countdown = context.state.countdown {
                        HStack(spacing: 12) {
                            Image(systemName: "figure.fall")
                                .foregroundColor(.red)
                            Text("Emergency in \(countdown)s")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.red)
                            if let cancelURL = URL(string: "guardian://cancel-alert") {
                                Link(destination: cancelURL) {
                                    Label("Cancel", systemImage: "xmark.circle")
                                        .font(.system(size: 12, weight: .bold))
                                }
                                .tint(.white)
                            }
                        }
                    } else {
                        Text("Monitoring Active")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            } compactLeading: {
                Circle()
                    .fill(statusColor(context.state.status))
                    .frame(width: 8, height: 8)
            } compactTrailing: {
                Text("\(context.state.gaitScore)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            } minimal: {
                Circle()
                    .fill(statusColor(context.state.status))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private func lockScreenView(context: ActivityViewContext<FallDetectionAttributes>) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor(context.state.status))
                        .frame(width: 10, height: 10)
                    Text(statusTitle(context.state.status))
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(1)
                }

                Text(context.attributes.userName)
                    .font(.system(size: 16, weight: .bold))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("GAIT")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(.secondary)

                Text("\(context.state.gaitScore)")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))

                if context.state.alertActive {
                    Text("ALERT")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                        .tracking(1)
                }
            }
        }
        .padding(16)
    }

    private func statusColor(_ status: MonitoringStatus) -> Color {
        switch status {
        case .active:      return .green
        case .alert:       return .red
        case .dispatching: return .orange
        case .inactive:    return .gray
        }
    }

    private func statusTitle(_ status: MonitoringStatus) -> String {
        switch status {
        case .active: return "Monitoring Active"
        case .alert: return "Fall Detected"
        case .dispatching: return "Dispatching"
        case .inactive: return "Inactive"
        }
    }
}
