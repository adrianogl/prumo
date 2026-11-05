import SwiftUI
import PRumoKit

struct IntegrationsSettingsView: View {
    let store: IntegrationSettingsStore
    @FocusState private var focusedPrefix: UUID?

    var body: some View {
        Form {
            Section {
                if !store.jira.sites.isEmpty {
                    HStack {
                        Text(IntegrationsSettingsText.prefix)
                            .frame(width: IntegrationsSettingsMetrics.prefixWidth, alignment: .leading)
                        Text(IntegrationsSettingsText.site)
                    }
                    .font(.system(size: IntegrationsSettingsMetrics.hintSize))
                    .foregroundStyle(.secondary)
                }
                ForEach(store.jira.sites) { site in
                    siteRow(site)
                }
                Button(IntegrationsSettingsText.addPrefix) {
                    store.jira.sites.append(JiraSite(prefix: "", host: ""))
                }
            } header: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(IntegrationsSettingsText.jira)
                    Text(IntegrationsSettingsText.jiraNote)
                        .font(.system(size: IntegrationsSettingsMetrics.hintSize))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: focusedPrefix) { old, _ in
            if let old { normalizePrefix(of: old) }
        }
        .onDisappear { store.jira.sites.forEach { normalizePrefix(of: $0.id) } }
    }

    private func siteRow(_ site: JiraSite) -> some View {
        let id = site.id
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                TextField(
                    IntegrationsSettingsText.prefix, text: field(id, \.prefix),
                    prompt: Text(IntegrationsSettingsText.prefixPlaceholder))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedPrefix, equals: id)
                    .onSubmit { normalizePrefix(of: id) }
                    .frame(width: IntegrationsSettingsMetrics.prefixWidth)
                TextField(
                    IntegrationsSettingsText.site, text: field(id, \.host),
                    prompt: Text(IntegrationsSettingsText.sitePlaceholder))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                Button {
                    store.jira.sites.removeAll { $0.id == id }
                } label: {
                    Label(IntegrationsSettingsText.remove, systemImage: IntegrationsSettingsSymbol.remove)
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help(IntegrationsSettingsText.remove)
            }
            if site.host.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(IntegrationsSettingsText.noSite)
                    .font(.system(size: IntegrationsSettingsMetrics.hintSize))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func field(_ id: UUID, _ keyPath: WritableKeyPath<JiraSite, String>) -> Binding<String> {
        Binding(
            get: { store.jira.sites.first { $0.id == id }?[keyPath: keyPath] ?? "" },
            set: { value in
                guard let index = store.jira.sites.firstIndex(where: { $0.id == id }) else { return }
                store.jira.sites[index][keyPath: keyPath] = value
            })
    }

    private func normalizePrefix(of id: UUID) {
        guard let index = store.jira.sites.firstIndex(where: { $0.id == id }) else { return }
        let raw = store.jira.sites[index].prefix
        let normalized = JiraKeyDetector.normalizedPrefix(raw)
            ?? raw.trimmingCharacters(in: .whitespaces).uppercased()
        if normalized != raw { store.jira.sites[index].prefix = normalized }
    }
}
