import SwiftUI

struct Wordmark: View {
    let size: CGFloat

    init(size: CGFloat) {
        self.size = size
    }

    var body: some View {
        Text("\(Text("PR").foregroundStyle(Color.prumoCaramel))umo")
            .font(.system(size: size, weight: .bold))
            .tracking(-0.03 * size)
    }
}
