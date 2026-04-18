import SwiftUI

enum LEDStatus {
    case active, warning, alert, offline

    var color: Color {
        switch self {
        case .active:  return Theme.ledGreen
        case .warning: return Theme.ledYellow
        case .alert:   return Theme.ledRed
        case .offline: return Theme.textMuted
        }
    }

    var label: String {
        switch self {
        case .active:  return "ONLINE"
        case .warning: return "WARNING"
        case .alert:   return "ALERT"
        case .offline: return "OFFLINE"
        }
    }

    var shouldPulse: Bool {
        self != .offline
    }
}

struct LEDIndicator: View {
    var status: LEDStatus
    var size: CGFloat = 10
    var showLabel: Bool = true

    @State private var isPulsing = false
    @State private var horizontalShift = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: size, height: size)
                .shadow(color: status.color.opacity(status.shouldPulse ? 0.8 : 0), radius: 6, x: 0, y: 0)
                .scaleEffect(isPulsing ? 1.15 : 1.0)
                .offset(x: status.shouldPulse ? (horizontalShift ? 1.6 : -1.6) : 0, y: 0)
                .animation(
                    status.shouldPulse
                        ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
                        : .default,
                    value: isPulsing
                )
                .animation(
                    status.shouldPulse
                        ? .easeInOut(duration: 1.4).repeatForever(autoreverses: true)
                        : .default,
                    value: horizontalShift
                )
                .onAppear {
                    isPulsing = status.shouldPulse
                    horizontalShift = status.shouldPulse
                }

            if showLabel {
                Text(status.label)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundColor(status.color)
            }
        }
    }
}
