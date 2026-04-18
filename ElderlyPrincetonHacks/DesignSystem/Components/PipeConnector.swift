import SwiftUI

struct PipeConnector: View {
    var height: CGFloat = 12

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2)
            .fill(Theme.recessed)
            .frame(height: height)
            .shadow(
                color: Color.black.opacity(0.12),
                radius: 2, x: 0, y: 2
            )
            .overlay(
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color.clear,
                                Color.black.opacity(0.08)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
    }
}
