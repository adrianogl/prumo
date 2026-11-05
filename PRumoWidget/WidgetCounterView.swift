import SwiftUI

struct WidgetCounterView: View {
    let value: Int
    let label: String
    let numberSize: CGFloat
    let highlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetMetrics.numberLabelSpacing) {
            Text("\(value)")
                .font(.system(size: numberSize, weight: .bold))
                .foregroundStyle(highlighted ? Color.prumoCaramel : Color.primary)
            Text(label)
                .font(.system(size: WidgetMetrics.counterLabelSize))
                .foregroundStyle(.secondary)
        }
    }
}
