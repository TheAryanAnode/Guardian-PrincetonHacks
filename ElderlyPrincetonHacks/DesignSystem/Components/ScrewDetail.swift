import SwiftUI

struct ScrewDetail: View {
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.15),
                        Color.clear
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 2
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.black.opacity(0.05), lineWidth: 0.5)
            )
            .overlay(
                Rectangle()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: size * 0.6, height: 1)
            )
    }
}

struct CornerScrews: View {
    var inset: CGFloat = 12
    var screwSize: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ScrewDetail(size: screwSize)
                .position(x: inset, y: inset)
            ScrewDetail(size: screwSize)
                .position(x: geo.size.width - inset, y: inset)
            ScrewDetail(size: screwSize)
                .position(x: inset, y: geo.size.height - inset)
            ScrewDetail(size: screwSize)
                .position(x: geo.size.width - inset, y: geo.size.height - inset)
        }
    }
}
