import SwiftUI
import PRumoKit

struct RepositoryPicker: View {
    let organization: OrganizationStore
    let snapshot: Snapshot?
    let accounts: [Account]
    @State private var search = ""

    private var settings: OrganizationSettings { organization.settings }

    private var groups: [RepositoryGroup] {
        guard let snapshot else { return [] }
        return RepositoryCatalog.groups(
            snapshot: snapshot, known: settings.knownRepositories, favorites: settings.favorites,
            hideEmpty: settings.hideEmptyRepositories, search: search,
            accounts: accounts, repositoryAccounts: settings.repositoryAccounts)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PickerSearchField(prompt: FiltersText.searchRepository, text: $search)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(groups, id: \.pickerID) { group in
                        if let section = sectionHeader(for: group) {
                            PickerSectionTitle(title: section)
                        }
                        PickerGroupTitle(title: group.title)
                        ForEach(group.entries, id: \.name) { entry in
                            row(entry)
                        }
                    }
                }
            }
            .frame(maxHeight: FiltersMetrics.pickerListMaxHeight)
            .fixedSize(horizontal: false, vertical: true)
            Divider().padding(.vertical, FiltersMetrics.dividerVerticalPadding)
            Toggle(FiltersText.hideEmptyRepositories, isOn: hideEmpty)
                .toggleStyle(.checkbox)
                .font(.system(size: FiltersMetrics.pickerNoteFontSize))
                .foregroundStyle(.secondary)
                .padding(.horizontal, FiltersMetrics.pickerRowHorizontalPadding)
                .padding(.vertical, FiltersMetrics.pickerRowVerticalPadding)
            SaveViewRow(organization: organization)
        }
        .padding(FiltersMetrics.pickerPadding)
        .frame(width: FiltersMetrics.pickerWidth)
    }

    private func sectionHeader(for group: RepositoryGroup) -> String? {
        guard let section = group.section, let index = groups.firstIndex(of: group) else { return nil }
        let previous = index > 0 ? groups[index - 1].section : nil
        return previous == section ? nil : section
    }

    private var hideEmpty: Binding<Bool> {
        Binding(
            get: { organization.settings.hideEmptyRepositories },
            set: { organization.settings.hideEmptyRepositories = $0 })
    }

    private func row(_ entry: RepositoryEntry) -> some View {
        let selected = settings.filter.repositories.contains(entry.name)
        return HStack(spacing: FiltersMetrics.rowSpacing) {
            Button {
                toggleSelection(entry.name)
            } label: {
                HStack(spacing: FiltersMetrics.rowSpacing) {
                    checkbox(selected)
                    Text(entry.name)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: FiltersMetrics.rowSpacerMinLength)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
            Button {
                toggleFavorite(entry.name)
            } label: {
                Image(systemName: entry.isFavorite ? FiltersSymbol.favorite : FiltersSymbol.notFavorite)
                    .font(.system(size: FiltersMetrics.starSize))
                    .foregroundStyle(entry.isFavorite ? Color.prumoCaramel : Color.secondary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(entry.isFavorite ? FiltersText.unfavorite : FiltersText.favorite)
            .accessibilityLabel(entry.isFavorite ? FiltersText.unfavorite : FiltersText.favorite)
            Text("\(entry.count)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .font(.system(size: FiltersMetrics.pickerRowFontSize))
        .padding(.horizontal, FiltersMetrics.pickerRowHorizontalPadding)
        .padding(.vertical, FiltersMetrics.pickerRowVerticalPadding)
    }

    private func checkbox(_ selected: Bool) -> some View {
        RoundedRectangle(cornerRadius: FiltersMetrics.checkboxCornerRadius)
            .strokeBorder(selected ? Color.prumoCaramel : Color.secondary, lineWidth: FiltersMetrics.checkboxBorder)
            .background(
                selected ? Color.prumoCaramel : Color.clear,
                in: RoundedRectangle(cornerRadius: FiltersMetrics.checkboxCornerRadius))
            .overlay {
                if selected {
                    Image(systemName: FiltersSymbol.check)
                        .font(.system(size: FiltersMetrics.checkmarkSize, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: FiltersMetrics.checkboxSize, height: FiltersMetrics.checkboxSize)
    }

    private func toggleSelection(_ name: String) {
        if organization.settings.filter.repositories.contains(name) {
            organization.settings.filter.repositories.remove(name)
        } else {
            organization.settings.filter.repositories.insert(name)
        }
    }

    private func toggleFavorite(_ name: String) {
        if organization.settings.favorites.contains(name) {
            organization.settings.favorites.remove(name)
        } else {
            organization.settings.favorites.insert(name)
        }
    }
}
