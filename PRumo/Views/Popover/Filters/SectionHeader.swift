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
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .padding(.bottom, 2)
            .accessibilityAddTraits(.isHeader)
    }
}
