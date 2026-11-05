import SwiftUI

struct SectionHeader: View {
    let repository: String
    let count: Int

    private var parts: (owner: String?, name: String) {
        guard let slash = repository.firstIndex(of: "/") else { return (nil, repository) }
        return (String(repository[..<slash]), String(repository[repository.index(after: slash)...]))
    }

    var body: some View {
        HStack(spacing: FiltersMetrics.sectionHeaderSpacing) {
            HStack(spacing: 0) {
                if let owner = parts.owner {
                    Text(owner + FiltersText.sectionOwnerSeparator)
                        .foregroundStyle(.secondary)
                }
                Text(parts.name)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
            .font(.system(size: FiltersMetrics.sectionHeaderFontSize))
            .lineLimit(1)
            .truncationMode(.middle)
            Spacer(minLength: 0)
            Text("\(count)")
                .font(.system(size: FiltersMetrics.sectionCountFontSize, weight: .semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, FiltersMetrics.sectionCountHorizontalPadding)
                .padding(.vertical, FiltersMetrics.sectionCountVerticalPadding)
                .background(Capsule().fill(Color.prumoBadgeBackground))
        }
        .padding(.horizontal, FiltersMetrics.sectionHeaderHorizontalPadding)
        .padding(.vertical, FiltersMetrics.sectionHeaderVerticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(FiltersMetrics.sectionHeaderBackgroundOpacity))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(FiltersText.sectionHeader(repository: repository, count: count))
        .accessibilityAddTraits(.isHeader)
    }
}
