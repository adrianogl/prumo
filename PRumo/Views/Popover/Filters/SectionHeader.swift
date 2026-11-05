import SwiftUI

struct SectionHeader: View {
    let repository: String
    let count: Int

    var body: some View {
        Text(FiltersText.sectionHeader(repository: repository, count: count))
            .font(.system(size: FiltersMetrics.sectionHeaderFontSize, weight: .medium))
            .tracking(FiltersMetrics.sectionHeaderTracking)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, FiltersMetrics.sectionHeaderHorizontalPadding)
            .padding(.top, FiltersMetrics.sectionHeaderTopPadding)
            .padding(.bottom, FiltersMetrics.sectionHeaderBottomPadding)
            .accessibilityAddTraits(.isHeader)
    }
}
