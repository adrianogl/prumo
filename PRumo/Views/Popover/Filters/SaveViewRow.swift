import SwiftUI
import PRumoKit

struct SaveViewRow: View {
    let organization: OrganizationStore
    @State private var isEditing = false
    @State private var name = ""
    @FocusState private var isFocused: Bool

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isNameTaken: Bool {
        organization.settings.views.contains { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !isNameTaken
    }

    var body: some View {
        if isEditing {
            editor
        } else {
            PickerFooterButton(title: FiltersText.saveAsView, action: startEditing)
                .disabled(organization.settings.filter == RowFilter.empty)
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: FiltersMetrics.saveViewSpacing) {
            HStack(spacing: FiltersMetrics.saveViewSpacing) {
                TextField(FiltersText.viewNamePlaceholder, text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: FiltersMetrics.searchFontSize))
                    .focused($isFocused)
                    .onSubmit(save)
                    .onKeyPress(.escape) {
                        stopEditing()
                        return .handled
                    }
                    .padding(.horizontal, FiltersMetrics.searchHorizontalPadding)
                    .padding(.vertical, FiltersMetrics.searchVerticalPadding)
                    .background(
                        Color.prumoBadgeBackground,
                        in: RoundedRectangle(cornerRadius: FiltersMetrics.searchCornerRadius)
                    )
                Button(FiltersText.save, action: save)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(Color.prumoCaramel)
                    .disabled(!canSave)
                Button(action: stopEditing) {
                    Image(systemName: FiltersSymbol.remove)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel(FiltersText.cancel)
            }
            if isNameTaken {
                Text(FiltersText.viewNameTaken)
                    .font(.system(size: FiltersMetrics.chipFontSize))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, FiltersMetrics.pickerRowHorizontalPadding)
        .padding(.vertical, FiltersMetrics.pickerRowVerticalPadding)
        .onAppear { isFocused = true }
    }

    private func startEditing() {
        name = ""
        isEditing = true
    }

    private func stopEditing() {
        isEditing = false
        name = ""
    }

    private func save() {
        guard canSave else { return }
        organization.settings.views.append(SavedView(name: trimmedName, filter: organization.settings.filter))
        stopEditing()
    }
}
