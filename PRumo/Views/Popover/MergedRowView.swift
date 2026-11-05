import SwiftUI
import AppKit
import PRumoKit

struct MergedRowView: View {
    let item: MergedPullRequest
    @State private var hovering = false

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = PopoverText.clockFormat
        return formatter
    }()

    private var subtitle: String {
        PopoverText.mergedSubtitle(
            repository: item.repository, number: item.number, time: Self.clock.string(from: item.mergedAt))
    }

    var body: some View {
        Button {
            NSWorkspace.shared.open(item.url)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: PopoverSymbol.merged)
                    .font(.system(size: PopoverMetrics.mergedIconSize, weight: .semibold))
                    .foregroundStyle(Color(nsColor: .systemGreen))
                    .frame(width: PopoverMetrics.dotSize)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(hovering ? Color.primary.opacity(0.04) : Color.clear)
        .onHover { hovering = $0 }
        .accessibilityLabel([item.title, subtitle].joined(separator: ", "))
    }
}
