import SwiftUI

enum NeuButtonVariant {
    case primary, secondary, ghost
}

struct NeuButton: View {
    let title: String
    var icon: String? = nil
    var variant: NeuButtonVariant = .primary
    var isFullWidth: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .default))
                    .tracking(1.2)
            }
            .textCase(.uppercase)
            .foregroundColor(foregroundColor)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(minHeight: 48)
            .padding(.horizontal, 24)
            .padding(.vertical, 4)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
            .shadow(
                color: isPressed ? .clear : darkShadow,
                radius: isPressed ? 0 : 4,
                x: isPressed ? 0 : 4,
                y: isPressed ? 0 : 4
            )
            .shadow(
                color: isPressed ? .clear : lightShadow,
                radius: isPressed ? 0 : 4,
                x: isPressed ? 0 : -4,
                y: isPressed ? 0 : -4
            )
            .overlay(
                isPressed
                    ? RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous)
                        .stroke(Theme.chassis, lineWidth: 4)
                        .shadow(color: Theme.cardDarkShadow, radius: 6, x: 6, y: 6)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
                    : nil
            )
            .overlay(
                isPressed
                    ? RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous)
                        .stroke(Theme.chassis, lineWidth: 4)
                        .shadow(color: Theme.cardLightShadow, radius: 6, x: -6, y: -6)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
                    : nil
            )
            .offset(y: isPressed ? 2 : 0)
            .animation(Theme.quickPress, value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }

    private var foregroundColor: Color {
        switch variant {
        case .primary:   return Theme.accentFg
        case .secondary: return Theme.textPrimary
        case .ghost:     return Theme.textMuted
        }
    }

    private var background: some ShapeStyle {
        switch variant {
        case .primary:   return AnyShapeStyle(Theme.accent)
        case .secondary: return AnyShapeStyle(Theme.chassis)
        case .ghost:     return AnyShapeStyle(Color.clear)
        }
    }

    private var darkShadow: Color {
        switch variant {
        case .primary:   return Color(hex: "#a6323c").opacity(0.4)
        case .secondary: return Theme.cardDarkShadow
        case .ghost:     return .clear
        }
    }

    private var lightShadow: Color {
        switch variant {
        case .primary:   return Color(hex: "#ff646e").opacity(0.4)
        case .secondary: return Theme.cardLightShadow
        case .ghost:     return .clear
        }
    }
}
