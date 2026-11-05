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
            .padding(.bottom, FiltersMetrics.groupTitleBottomPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct PickerSearchField: View {
    let prompt: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: FiltersMetrics.searchContentSpacing) {
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

struct PickerViewChip: View {
    let name: String
    let isOn: Bool
    let apply: () -> Void
    let delete: () -> Void
    @State private var isHovering = false

    private var removeIcon: some View {
        Image(systemName: FiltersSymbol.removeView)
            .font(.system(size: FiltersMetrics.viewChipRemoveSize))
    }

    var body: some View {
        Button(action: apply) {
            HStack(spacing: FiltersMetrics.viewChipRemoveSpacing) {
                Text(name)
                    .font(.system(size: FiltersMetrics.chipFontSize, weight: .medium))
                    .lineLimit(1)
                    .fixedSize()
                    .foregroundStyle(isOn ? Color.white : Color.primary)
                removeIcon.hidden()
            }
            .padding(.leading, FiltersMetrics.chipHorizontalPadding)
            .padding(.trailing, FiltersMetrics.viewChipRemoveTrailingPadding)
            .padding(.vertical, FiltersMetrics.chipVerticalPadding)
            .background(isOn ? Color.prumoCaramel : Color.prumoBadgeBackground, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .overlay(alignment: .trailing) {
            Button(action: delete) {
                removeIcon
                    .foregroundStyle(isOn ? Color.white.opacity(0.8) : Color.secondary)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .opacity(isHovering ? 1 : 0)
            .allowsHitTesting(isHovering)
            .help(FiltersText.deleteView)
            .accessibilityLabel(FiltersText.deleteView(named: name))
            .padding(.trailing, FiltersMetrics.viewChipRemoveTrailingPadding)
        }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button(FiltersText.deleteView, action: delete)
        }
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
