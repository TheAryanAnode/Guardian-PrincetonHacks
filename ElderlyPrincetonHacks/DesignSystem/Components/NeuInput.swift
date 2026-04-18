import SwiftUI

struct NeuInput: View {
    let placeholder: String
    @Binding var text: String
    var icon: String? = nil
    var isSecure: Bool = false

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isFocused ? Theme.accent : Theme.textMuted)
                    .frame(width: 20)
            }

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .font(.system(.body, design: .monospaced))
            .foregroundColor(Theme.textPrimary)
            .focused($isFocused)
        }
        .padding(.horizontal, 20)
        .frame(minHeight: 56)
        .neuRecessed(radius: Theme.radiusMd)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMd, style: .continuous)
                .stroke(isFocused ? Theme.accent.opacity(0.5) : .clear, lineWidth: 2)
        )
        .shadow(
            color: isFocused ? Theme.accent.opacity(0.2) : .clear,
            radius: 8, x: 0, y: 0
        )
        .animation(Theme.smoothTransition, value: isFocused)
    }
}
