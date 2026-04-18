import SwiftUI

struct FallReasonView: View {
    let triggers: [FallTrigger]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("FALL DETECTED BECAUSE:")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundColor(Theme.textMuted)

            ForEach(triggers) { trigger in
                HStack(spacing: 10) {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 6, height: 6)

                    Image(systemName: trigger.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.accent)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(trigger.description)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                        Text(trigger.value)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.accent)
                    }

                    Spacer()
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .neuRecessed(radius: Theme.radiusMd)
            }
        }
    }
}
