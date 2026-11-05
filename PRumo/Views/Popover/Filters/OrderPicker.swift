import SwiftUI
import PRumoKit

struct OrderPicker: View {
    let organization: OrganizationStore
    let tab: ListTab

    private var ordering: TabOrdering { organization.settings.ordering(for: tab) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(RowSortOrder.allCases, id: \.self) { order in
                item(FiltersText.label(order), isOn: ordering.order == order) {
                    update { $0.order = order }
                }
            }
            Divider().padding(.vertical, FiltersMetrics.dividerVerticalPadding)
            item(FiltersText.groupByRepository, isOn: ordering.groupByRepository, highlights: false) {
                update { $0.groupByRepository.toggle() }
            }
            Text(FiltersText.orderNote)
                .font(.system(size: FiltersMetrics.pickerNoteFontSize))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, FiltersMetrics.pickerRowHorizontalPadding)
                .padding(.vertical, FiltersMetrics.pickerRowVerticalPadding)
        }
        .padding(FiltersMetrics.pickerPadding)
        .frame(width: FiltersMetrics.orderPickerWidth)
    }

    private func update(_ change: (inout TabOrdering) -> Void) {
        var next = ordering
        change(&next)
        organization.settings.setOrdering(next, for: tab)
    }

    private func item(
        _ title: String, isOn: Bool, highlights: Bool = true, action: @escaping () -> Void
    ) -> some View {
        let highlighted = isOn && highlights
        return Button(action: action) {
            HStack(spacing: FiltersMetrics.rowSpacing) {
                Image(systemName: FiltersSymbol.check)
                    .font(.system(size: FiltersMetrics.orderCheckSize, weight: .semibold))
                    .opacity(isOn ? 1 : 0)
                    .frame(width: FiltersMetrics.checkColumnWidth)
                Text(title)
                Spacer(minLength: 0)
            }
            .font(.system(size: FiltersMetrics.pickerRowFontSize))
            .foregroundStyle(highlighted ? Color.white : Color.primary)
            .padding(.horizontal, FiltersMetrics.pickerRowHorizontalPadding)
            .padding(.vertical, FiltersMetrics.pickerRowVerticalPadding)
            .background(
                highlighted ? Color.prumoCaramel : Color.clear,
                in: RoundedRectangle(cornerRadius: FiltersMetrics.pickerRowCornerRadius))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
