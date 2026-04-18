import SwiftUI

struct VentSlots: View {
    var count: Int = 3
    var height: CGFloat = 24
    var spacing: CGFloat = 4

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(0..<count, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Theme.recessed)
                    .frame(width: 1.5, height: height)
                    .shadow(
                        color: Color.black.opacity(0.1),
                        radius: 1, x: 1, y: 1
                    )
            }
        }
    }
}
