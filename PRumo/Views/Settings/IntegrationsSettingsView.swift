import SwiftUI
import PRumoKit

struct IntegrationsSettingsView: View {
    let store: IntegrationSettingsStore
    @FocusState private var focusedPrefix: UUID?

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                ForEach($store.jira.sites) { $site in
                    siteRow($site)
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
    }

    private func siteRow(_ site: Binding<JiraSite>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                TextField(IntegrationsSettingsText.prefix, text: site.prefix)
                    .focused($focusedPrefix, equals: site.wrappedValue.id)
                    .onSubmit { normalizePrefix(of: site.wrappedValue.id) }
                    .frame(width: IntegrationsSettingsMetrics.prefixWidth)
                TextField(
                    IntegrationsSettingsText.site, text: site.host,
                    prompt: Text(IntegrationsSettingsText.sitePlaceholder))
                Button {
                    store.jira.sites.removeAll { $0.id == site.wrappedValue.id }
                } label: {
                    Image(systemName: IntegrationsSettingsSymbol.remove)
                }
                .buttonStyle(.borderless)
                .help(IntegrationsSettingsText.remove)
            }
            if site.wrappedValue.host.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(IntegrationsSettingsText.noSite)
                    .font(.system(size: IntegrationsSettingsMetrics.hintSize))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func normalizePrefix(of id: UUID) {
        guard let index = store.jira.sites.firstIndex(where: { $0.id == id }) else { return }
        let raw = store.jira.sites[index].prefix
        let normalized = JiraKeyDetector.normalizedPrefix(raw)
            ?? raw.trimmingCharacters(in: .whitespaces).uppercased()
        if normalized != raw { store.jira.sites[index].prefix = normalized }
    }
}
