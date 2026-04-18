import SwiftUI

// MARK: - Card Elevation (Level +1)

struct NeuCardModifier: ViewModifier {
    var radius: CGFloat = Theme.radiusLg

    func body(content: Content) -> some View {
        content
            .background(Theme.chassis)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: Theme.cardDarkShadow, radius: 8, x: 8, y: 8)
            .shadow(color: Theme.cardLightShadow, radius: 8, x: -8, y: -8)
    }
}

// MARK: - Floating Elevation (Level +2)

struct NeuFloatingModifier: ViewModifier {
    var radius: CGFloat = Theme.radiusLg

    func body(content: Content) -> some View {
        content
            .background(Theme.chassis)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: Theme.cardDarkShadow, radius: 12, x: 12, y: 12)
            .shadow(color: Theme.cardLightShadow, radius: 12, x: -12, y: -12)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    .blur(radius: 0.5)
            )
    }
}

// MARK: - Pressed State (Active)

struct NeuPressedModifier: ViewModifier {
    var radius: CGFloat = Theme.radiusLg

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.chassis)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(Theme.chassis, lineWidth: 4)
                            .shadow(color: Theme.cardDarkShadow, radius: 6, x: 6, y: 6)
                            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(Theme.chassis, lineWidth: 4)
                            .shadow(color: Theme.cardLightShadow, radius: 6, x: -6, y: -6)
                            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    )
            )
    }
}

// MARK: - Recessed (Level -1, Inputs)

struct NeuRecessedModifier: ViewModifier {
    var radius: CGFloat = Theme.radiusMd

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.chassis)
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(Theme.chassis, lineWidth: 4)
                            .shadow(color: Theme.cardDarkShadow, radius: 4, x: 4, y: 4)
                            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .stroke(Theme.chassis, lineWidth: 4)
                            .shadow(color: Theme.cardLightShadow, radius: 4, x: -4, y: -4)
                            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    )
            )
    }
}

// MARK: - Glow (LED / Status)

struct NeuGlowModifier: ViewModifier {
    var color: Color = Theme.accent
    var radius: CGFloat = 10
    var spread: CGFloat = 2

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.6), radius: radius, x: 0, y: 0)
    }
}

// MARK: - View Extension

extension View {
    func neuCard(radius: CGFloat = Theme.radiusLg) -> some View {
        modifier(NeuCardModifier(radius: radius))
    }

    func neuFloating(radius: CGFloat = Theme.radiusLg) -> some View {
        modifier(NeuFloatingModifier(radius: radius))
    }

    func neuPressed(radius: CGFloat = Theme.radiusLg) -> some View {
        modifier(NeuPressedModifier(radius: radius))
    }

    func neuRecessed(radius: CGFloat = Theme.radiusMd) -> some View {
        modifier(NeuRecessedModifier(radius: radius))
    }

    func neuGlow(color: Color = Theme.accent, radius: CGFloat = 10) -> some View {
        modifier(NeuGlowModifier(color: color, radius: radius))
    }
}
