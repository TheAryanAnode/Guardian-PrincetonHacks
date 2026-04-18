import SwiftUI

enum Theme {

    // MARK: - Colors (Industrial Palette)

    static let chassis      = Color(hex: "#e0e5ec")
    static let panel        = Color(hex: "#f0f2f5")
    static let recessed     = Color(hex: "#d1d9e6")
    static let textPrimary  = Color(hex: "#2d3436")
    static let textMuted    = Color(hex: "#4a5568")
    static let accent       = Color(hex: "#ff4757")
    static let accentFg     = Color.white
    static let shadowDark   = Color(hex: "#babecc")
    static let shadowLight  = Color.white
    static let borderDark   = Color(hex: "#a3b1c6")

    static let darkPanel    = Color(hex: "#2d3436")
    static let darkSlate    = Color(hex: "#2c3e50")
    static let darkText     = Color(hex: "#a8b2d1")

    static let ledGreen     = Color(hex: "#22c55e")
    static let ledYellow    = Color(hex: "#eab308")
    static let ledRed       = Color(hex: "#ff4757")

    // MARK: - Shadows (Neumorphic Pairs)

    static func cardShadow() -> some View {
        EmptyView()
    }

    static let cardDarkShadow   = Color(hex: "#babecc")
    static let cardLightShadow  = Color.white

    // MARK: - Typography

    static let primaryFont   = "Inter"
    static let monoFont      = "JetBrains Mono"
    static let monoFallback  = Font.system(.body, design: .monospaced)

    // MARK: - Radii

    static let radiusSm: CGFloat   = 4
    static let radiusMd: CGFloat   = 8
    static let radiusLg: CGFloat   = 16
    static let radiusXl: CGFloat   = 24
    static let radius2xl: CGFloat  = 30

    // MARK: - Spacing

    static let spacingSm: CGFloat  = 8
    static let spacingMd: CGFloat  = 16
    static let spacingLg: CGFloat  = 24
    static let spacingXl: CGFloat  = 32
    static let spacing2xl: CGFloat = 48

    // MARK: - Mechanical Easing

    static let mechanicalEasing = Animation.interpolatingSpring(
        mass: 1.0,
        stiffness: 200,
        damping: 18,
        initialVelocity: 0
    )

    static let quickPress = Animation.easeOut(duration: 0.15)
    static let smoothTransition = Animation.easeInOut(duration: 0.3)
}
