import PRumoKit
import SwiftUI

struct MediumWidgetView: View {
    let entry: PRumoEntry

    var body: some View {
        VStack(alignment: .leading, spacing: WidgetMetrics.mediumSpacing) {
            Wordmark(size: WidgetMetrics.wordmarkSize)
            if entry.snapshot.connected {
                counters
                rows
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

    private var counters: some View {
        HStack(alignment: .top, spacing: WidgetMetrics.counterSpacing) {
            WidgetCounterView(
                value: entry.snapshot.toReview, label: WidgetText.toReview,
                numberSize: WidgetMetrics.counterNumberSize, highlighted: true
            )
            WidgetCounterView(
                value: entry.snapshot.ciFailing, label: WidgetText.ciFailing,
                numberSize: WidgetMetrics.counterNumberSize, highlighted: false
            )
            WidgetCounterView(
                value: entry.snapshot.readyToMerge, label: WidgetText.readyToMerge,
                numberSize: WidgetMetrics.counterNumberSize, highlighted: false
            )
        }
    }

    @ViewBuilder
    private var rows: some View {
        if entry.snapshot.items.isEmpty {
            Text(WidgetText.empty)
                .font(.system(size: WidgetMetrics.rowFontSize))
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: WidgetMetrics.rowSpacing) {
                ForEach(entry.snapshot.items.prefix(WidgetMetrics.maxRows)) { item in
                    Link(destination: WidgetLink.make(item.url)) {
                        HStack(spacing: WidgetMetrics.dotSpacing) {
                            Circle()
                                .fill(dotColor(item.reason))
                                .frame(width: WidgetMetrics.dotSize, height: WidgetMetrics.dotSize)
                            Text(label(item))
                                .font(.system(size: WidgetMetrics.rowFontSize))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    private func dotColor(_ reason: WidgetReason) -> Color {
        switch reason {
        case .ciFailing: .red
        case .staleReview: .orange
        case .readyToMerge: .green
        }
    }

    private func label(_ item: WidgetItem) -> String {
        switch item.reason {
        case .ciFailing:
            return "#\(item.number) \(item.title)"
        case .staleReview:
            let hours = item.waitingHours.map { " · \($0)h" } ?? ""
            return "#\(item.number) \(item.title)\(hours)"
        case .readyToMerge:
            return "#\(item.number) \(WidgetText.readyItem)"
        }
    }
}
