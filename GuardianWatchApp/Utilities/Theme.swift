import SwiftUI

/// Watch-friendly palette: dark background, large legible accents.
/// We intentionally drop the heavy "neumorphic" iOS look — flat, high-contrast,
/// readable at a glance is what watchOS HIG asks for.
enum Theme {
    static let background  = Color.black
    static let surface     = Color(white: 0.12)
    static let surfaceHi   = Color(white: 0.18)
    static let textPrimary = Color.white
    static let textMuted   = Color(white: 0.65)

    static let accent      = Color(hex: "#ff4757")
    static let accentSoft  = Color(hex: "#ff4757").opacity(0.18)

    static let ledGreen    = Color(hex: "#22c55e")
    static let ledYellow   = Color(hex: "#eab308")
    static let ledRed      = Color(hex: "#ff4757")

    /// Corner radius tuned for round bezel.
    static let radius: CGFloat = 14

    static func riskColor(_ level: GaitRiskLevel) -> Color {
        switch level {
        case .low:      return ledGreen
        case .moderate: return ledYellow
        case .high:     return ledRed
        }
    }
}

/// Reusable Watch-style card. Replaces the iOS NeuCard.
struct WatchCard<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    }
}
