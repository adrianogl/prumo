import SwiftUI
import PRumoKit

struct FiltersSettingsView: View {
    let store: OrganizationStore

    private var mutedPullRequests: [MutedPullRequest] {
        store.settings.marks.muted.values.sorted { $0.mutedAt > $1.mutedAt }
    }

    var body: some View {
        Form {
            Section {
                Toggle(FiltersSettingsText.ignoreDrafts, isOn: ignoreDrafts)
                hint(FiltersSettingsText.ignoreDraftsHint)
                Toggle(FiltersSettingsText.includeTeam, isOn: includeTeam)
                hint(FiltersSettingsText.includeTeamHint)
            }
            Section(FiltersSettingsText.views) {
                if store.settings.views.isEmpty {
                    hint(FiltersSettingsText.noViews)
                }
                ForEach(store.settings.views) { view in
                    viewRow(view)
                }
            }
            Section(FiltersSettingsText.muted) {
                if mutedPullRequests.isEmpty {
                    hint(FiltersSettingsText.noMuted)
                }
                ForEach(mutedPullRequests, id: \.id) { pr in
                    mutedRow(pr)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: FiltersSettingsMetrics.hintSize))
            .foregroundStyle(.secondary)
    }

    private func viewRow(_ view: SavedView) -> some View {
        let id = view.id
        return HStack {
            TextField(FiltersSettingsText.viewName, text: viewName(id))
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
            Button {
                store.settings.views.removeAll { $0.id == id }
            } label: {
                Label(FiltersSettingsText.remove, systemImage: FiltersSettingsSymbol.remove)
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help(FiltersSettingsText.remove)
        }
    }

    private func mutedRow(_ pr: MutedPullRequest) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(FiltersSettingsText.mutedTitle(
                    MutedTitleParts(repository: pr.repository, number: pr.number, title: pr.title)))
                    .lineLimit(1)
                    .truncationMode(.tail)
                hint(FiltersSettingsText.mutedOn(pr.mutedAt))
            }
            Spacer()
            Button(FiltersSettingsText.unmute) { store.unmute(id: pr.id) }
        }
    }

    private var ignoreDrafts: Binding<Bool> {
        Binding(
            get: { store.settings.ignoreDraftsInReview },
            set: { store.settings.ignoreDraftsInReview = $0 })
    }

    private var includeTeam: Binding<Bool> {
        Binding(
            get: { store.settings.includeTeamRequests },
            set: { store.settings.includeTeamRequests = $0 })
    }

    private func viewName(_ id: UUID) -> Binding<String> {
        Binding(
            get: { store.settings.views.first { $0.id == id }?.name ?? "" },
            set: { value in
                guard let index = store.settings.views.firstIndex(where: { $0.id == id }) else { return }
                store.settings.views[index].name = value
            })
    }
}
