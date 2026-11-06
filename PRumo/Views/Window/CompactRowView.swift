import SwiftUI
import PRumoKit

struct CompactRowView: View {
    let presentation: RowPresentation
    let age: String
    let reference: String
    let repository: String
    let isStale: Bool
    let isNew: Bool
    let session: TerminalSessionStatus?

    var body: some View {
        HStack(alignment: .top, spacing: MainWindowMetrics.rowSpacing) {
            Circle()
                .fill(presentation.dot.color)
                .frame(width: MainWindowMetrics.rowDotSize, height: MainWindowMetrics.rowDotSize)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(presentation.title)
                    .font(.system(size: MainWindowMetrics.titleFontSize, weight: .medium))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(repository) \(reference) · \(age)")
                    .font(.system(size: MainWindowMetrics.subtitleFontSize))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if !presentation.badges.isEmpty {
                    FlowLayout(spacing: PopoverMetrics.badgeSpacing, lineSpacing: PopoverMetrics.badgeLineSpacing) {
                        ForEach(Array(presentation.badges.enumerated()), id: \.offset) { index, badge in
                            BadgeView(badge: badge, tint: index == presentation.jiraBadgeIndex ? Color.jiraBlue : nil)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
            VStack(spacing: 6) {
                if isNew {
                    Circle()
                        .fill(Color.prumoCaramel)
                        .frame(width: PopoverMetrics.newDotSize, height: PopoverMetrics.newDotSize)
                }
                if let session {
                    Image(systemName: TerminalSymbol.indicator)
                        .font(.system(size: 10))
                        .foregroundStyle(session.color)
                        .help(session.label)
                        .accessibilityLabel(session.label)
                }
            }
            .padding(.top, 4)
        }
        .padding(.vertical, MainWindowMetrics.rowVerticalPadding)
        .opacity(isStale ? PopoverMetrics.staleAccountOpacity : 1)
        .accessibilityElement(children: .combine)
    }
}
