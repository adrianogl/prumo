import SwiftUI
import PRumoKit

struct ProviderIcon: View {
    let kind: ProviderKind
    let size: CGFloat

    var body: some View {
        Image(ProviderSymbol.asset(kind))
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
