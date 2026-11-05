import PRumoKit
import SwiftUI

struct WidgetFooterView: View {
    let entry: PRumoEntry

    var body: some View {
        if let updatedAt = staleDate {
            Text("\(WidgetText.updatedAt) \(WidgetClock.string(from: updatedAt))")
                .font(.system(size: WidgetMetrics.footerSize))
                .foregroundStyle(.secondary)
        }
    }

    private var staleDate: Date? {
        let updatedAt = entry.snapshot.updatedAt
        guard updatedAt.timeIntervalSince1970 > 0 else { return nil }
        guard entry.date.timeIntervalSince(updatedAt) > WidgetMetrics.staleLimit else { return nil }
        return updatedAt
    }
}
