import SwiftUI

struct Wordmark: View {
    let size: CGFloat

    init(size: CGFloat) {
        self.size = size
    }

    var body: some View {
        (Text("PR").foregroundStyle(Color.prumoCaramel) + Text("umo"))
            .font(.system(size: size, weight: .bold))
            .tracking(-0.03 * size)
    }
}
