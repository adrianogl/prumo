import SwiftUI
import PRumoKit

struct FilterChipsView: View {
    let organization: OrganizationStore
    let staleHours: Int

    private var chips: [FilterChip] {
        FilterChips.chips(organization.settings.filter, staleHours: staleHours)
    }

    var body: some View {
        let chips = chips
        if !chips.isEmpty {
            HStack(alignment: .top, spacing: FiltersMetrics.chipSpacing) {
                FlowLayout(spacing: FiltersMetrics.chipSpacing, lineSpacing: FiltersMetrics.chipLineSpacing) {
                    ForEach(chips, id: \.key) { chip in
                        chipView(chip)
                    }
                }
                Spacer(minLength: 0)
                Button(FiltersText.clear) {
                    organization.settings.filter = .empty
                }
                .buttonStyle(.plain)
                .font(.system(size: FiltersMetrics.clearFontSize))
                .foregroundStyle(.secondary)
            }
        }
    }

    private func chipView(_ chip: FilterChip) -> some View {
        Button {
            organization.settings.filter = organization.settings.filter.removing(chip.key)
        } label: {
            HStack(spacing: FiltersMetrics.chipContentSpacing) {
                Text(chip.label)
                    .lineLimit(1)
                Image(systemName: FiltersSymbol.remove)
                    .font(.system(size: FiltersMetrics.chipRemoveSize, weight: .bold))
            }
            .fixedSize()
            .font(.system(size: FiltersMetrics.chipFontSize, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, FiltersMetrics.chipHorizontalPadding)
            .padding(.vertical, FiltersMetrics.chipVerticalPadding)
            .background(Color.prumoCaramel, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(FiltersText.removeFilter)
        .accessibilityLabel(FiltersText.removeChip(chip.label))
    }
}
