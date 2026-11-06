import SwiftUI
import PRumoKit

struct ClonesManagerView: View {
    let store: ClaudeSettingsStore
    let relevant: Set<String>
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var scope: CloneScope
    @State private var toggledOwners: Set<String> = []
    @State private var manualError: String?

    init(store: ClaudeSettingsStore, relevant: Set<String>) {
        self.store = store
        self.relevant = relevant
        _scope = State(initialValue: relevant.isEmpty ? .all : .relevant)
    }

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var expandsByDefault: Bool {
        isSearching || scope == .relevant
    }

    private var groups: [CloneGroup] {
        CloneListing.groups(
            repositories: store.repositories, relevant: relevant, onlyRelevant: scope == .relevant,
            query: query, path: path(for:))
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar.padding()
            Divider()
            content
            Divider()
            footer.padding()
        }
        .frame(width: ClonesManagerMetrics.width, height: ClonesManagerMetrics.height)
        .onChange(of: scope) { toggledOwners = [] }
        .onChange(of: isSearching) { toggledOwners = [] }
    }

    private var toolbar: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: ClonesManagerSymbol.search).foregroundStyle(.secondary)
                TextField(ClonesManagerText.searchPlaceholder, text: $query)
                    .textFieldStyle(.plain)
            }
            .padding(6)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            Picker(ClonesManagerText.title, selection: $scope) {
                ForEach(CloneScope.allCases) { scope in
                    Text(scope.label).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
    }

    @ViewBuilder
    private var content: some View {
        let groups = groups
        if groups.isEmpty {
            Text(store.isScanning ? ClaudeSettingsText.scanningClones : ClaudeSettingsText.noClones)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(groups, id: \.owner) { group in
                    DisclosureGroup(isExpanded: expansion(for: group.owner)) {
                        ForEach(group.repositories, id: \.self) { row($0) }
                    } label: {
                        Text(String(format: ClonesManagerText.groupTitle, group.owner, group.repositories.count))
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }

    private func row(_ repository: String) -> some View {
        HStack {
            Text(name(of: repository))
            Text(path(for: repository))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            if store.settings.cloneOverrides[repository] != nil {
                Text(ClonesManagerText.manual).foregroundStyle(.secondary)
            }
            Spacer()
            Button(ClonesManagerText.change) {
                if let url = FolderPicker.choose(prompt: ClaudeSettingsText.chooseFolderPrompt) {
                    store.setOverride(repository: repository, path: url)
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button(ClonesManagerText.addManually) { addManually() }
                Button(ClonesManagerText.rescan) {
                    Task { await store.rescan() }
                }
                .disabled(store.isScanning)
                if store.isScanning {
                    ProgressView().controlSize(.small)
                }
                Spacer()
                Button(ClonesManagerText.done) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            if let manualError {
                Text(manualError)
                    .font(.system(size: ClaudeSettingsMetrics.hintSize))
                    .foregroundStyle(Color.statusBad)
            }
        }
    }

    private func expansion(for owner: String) -> Binding<Bool> {
        Binding(
            get: { expandsByDefault != toggledOwners.contains(owner) },
            set: { isExpanded in
                if isExpanded == expandsByDefault {
                    toggledOwners.remove(owner)
                } else {
                    toggledOwners.insert(owner)
                }
            }
        )
    }

    private func name(of repository: String) -> String {
        repository.split(separator: "/", maxSplits: 1).last.map(String.init) ?? repository
    }

    private func path(for repository: String) -> String {
        if let override = store.settings.cloneOverrides[repository] { return override }
        let url = CloneResolver.pick(repository: repository, scanned: store.scanned, overrides: [:])
        return url.map { store.abbreviate($0.path) } ?? ""
    }

    private func addManually() {
        manualError = nil
        guard let url = FolderPicker.choose(prompt: ClaudeSettingsText.chooseFolderPrompt) else { return }
        Task {
            let result = try? await SystemProcessRunner().run(
                "/usr/bin/git", ["-C", url.path, "remote", "get-url", "origin"])
            guard let result, result.status == 0,
                  let repository = RemoteURL.repository(from: result.stdout)
            else {
                manualError = ClonesManagerText.notGitHubRepository
                return
            }
            store.setOverride(repository: repository, path: url)
        }
    }
}
