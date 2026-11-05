import PRumoKit
import SwiftUI

struct SmallWidgetView: View {
    let entry: PRumoEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetMetrics.smallSpacing) {
            Wordmark(size: WidgetMetrics.wordmarkSize)
            if entry.snapshot.connected {
                WidgetCounterView(
                    value: entry.snapshot.toReview, label: WidgetText.toReview,
                    numberSize: WidgetMetrics.smallCounterNumberSize, highlighted: true
                )
                WidgetCounterView(
                    value: entry.snapshot.ciFailing, label: WidgetText.ciFailing,
                    numberSize: WidgetMetrics.smallCounterNumberSize, highlighted: false
                )
                Spacer(minLength: 0)
                WidgetFooterView(entry: entry)
            } else {
                Text(WidgetText.disconnected)
                    .font(.system(size: WidgetMetrics.rowFontSize))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(WidgetMetrics.padding)
    }
}
