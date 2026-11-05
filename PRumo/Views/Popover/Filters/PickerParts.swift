import SwiftUI

struct PickerGroupTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: FiltersMetrics.groupTitleFontSize, weight: .medium))
            .tracking(FiltersMetrics.groupTitleTracking)
            .foregroundStyle(.secondary)
            .padding(.horizontal, FiltersMetrics.pickerRowHorizontalPadding)
            .padding(.top, FiltersMetrics.pickerPadding)
            .padding(.bottom, 3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PickerSearchField: View {
    let prompt: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: FiltersSymbol.search)
                .foregroundStyle(.secondary)
            TextField(prompt, text: $text)
                .textFieldStyle(.plain)
        }
        .font(.system(size: FiltersMetrics.searchFontSize))
        .padding(.horizontal, FiltersMetrics.searchHorizontalPadding)
        .padding(.vertical, FiltersMetrics.searchVerticalPadding)
        .background(Color.prumoBadgeBackground, in: RoundedRectangle(cornerRadius: FiltersMetrics.searchCornerRadius))
    }
}

struct PickerToggleChip: View {
    let title: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: FiltersMetrics.chipFontSize, weight: .medium))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .padding(.horizontal, FiltersMetrics.chipHorizontalPadding)
                .padding(.vertical, FiltersMetrics.chipVerticalPadding)
                .background(isOn ? Color.prumoCaramel : Color.prumoBadgeBackground, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

struct PickerFooterButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: FiltersMetrics.pickerNoteFontSize))
                .foregroundStyle(.secondary)
                .padding(.horizontal, FiltersMetrics.pickerRowHorizontalPadding)
                .padding(.vertical, FiltersMetrics.pickerRowVerticalPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
