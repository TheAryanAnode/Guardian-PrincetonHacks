import SwiftUI

struct NeuCard<Content: View>: View {
    var showScrews: Bool = true
    var showVents: Bool = false
    var elevated: Bool = false
    var radius: CGFloat = Theme.radiusLg
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            content()
                .padding(showScrews ? 20 : 16)

            if showScrews {
                CornerScrews(inset: 12, screwSize: 7)
                    .allowsHitTesting(false)
            }

            if showVents {
                VStack {
                    HStack {
                        Spacer()
                        VentSlots()
                            .padding(.top, 10)
                            .padding(.trailing, 10)
                    }
                    Spacer()
                }
                .allowsHitTesting(false)
            }
        }
        .if(elevated) { view in
            view.neuFloating(radius: radius)
        }
        .if(!elevated) { view in
            view.neuCard(radius: radius)
        }
    }
}

private extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
