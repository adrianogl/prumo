import SwiftUI
import PRumoKit

struct ClaudeSettingsView: View {
    let store: ClaudeSettingsStore
    @State private var manualError: String?
    @State private var lastCustomTemplate = ""

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                templateField(ClaudeSettingsText.reviewTemplate, hint: ClaudeSettingsText.reviewVariables, text: $store.settings.reviewTemplate)
                templateField(ClaudeSettingsText.ciTemplate, hint: ClaudeSettingsText.ciVariables, text: $store.settings.ciTemplate)
                templateField(ClaudeSettingsText.conflictTemplate, hint: ClaudeSettingsText.conflictVariables, text: $store.settings.conflictTemplate)
                templateField(ClaudeSettingsText.commentsTemplate, hint: ClaudeSettingsText.commentsVariables, text: $store.settings.commentsTemplate)
                commandField(text: $store.settings.command)
                TextField(ClaudeSettingsText.flags, text: $store.settings.extraFlags, prompt: Text(ClaudeSettingsText.flagsPlaceholder))
                    .font(.system(.body, design: .monospaced))
            }
            Section {
                Picker(ClaudeSettingsText.terminal, selection: terminalChoice) {
                    ForEach(TerminalChoice.allCases) { choice in
                        Text(choice.label).tag(choice)
                    }
                }
                if case .custom = store.settings.terminal {
                    VStack(alignment: .leading, spacing: 2) {
                        TextField(ClaudeSettingsText.customTemplate, text: customTemplate)
                            .font(.system(.body, design: .monospaced))
                        hint(ClaudeSettingsText.customHint)
                    }
                }
                folderRow(ClaudeSettingsText.clonesRoot, path: store.settings.clonesRoot) { url in
                    store.setClonesRoot(url)
                    Task { await store.rescan() }
                }
                folderRow(ClaudeSettingsText.worktreesRoot, path: store.settings.worktreesRoot) { url in
                    store.setWorktreesRoot(url)
                }
            }
            Section {
                clonesList
            } header: {
                clonesHeader
            }
            Section {
                Toggle(ClaudeSettingsText.removeWorktree, isOn: $store.settings.removeWorktreeOnClose)
            }
        }
        .formStyle(.grouped)
        .task { await store.rescan() }
    }

    private func templateField(_ title: String, hint hintText: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).fontWeight(.semibold)
            TextField(title, text: text, axis: .vertical)
                .labelsHidden()
                .lineLimit(ClaudeSettingsMetrics.templateLines)
                .font(.system(.body, design: .monospaced))
            hint(hintText)
        }
    }

    private func commandField(text: Binding<String>) -> some View {
        let value = text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let isInvalid = !value.isEmpty && !ClaudeCommandName.isValid(value)
        return VStack(alignment: .leading, spacing: 2) {
            TextField(ClaudeSettingsText.command, text: text, prompt: Text(ClaudeSettingsText.commandPlaceholder))
                .font(.system(.body, design: .monospaced))
            hint(ClaudeSettingsText.commandHint)
            if isInvalid {
                Text(ClaudeSettingsText.commandInvalid)
                    .font(.system(size: ClaudeSettingsMetrics.hintSize))
                    .foregroundStyle(.red)
            }
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: ClaudeSettingsMetrics.hintSize))
            .foregroundStyle(.secondary)
    }

    private func folderRow(_ title: String, path: String, onChoose: @escaping (URL) -> Void) -> some View {
        LabeledContent(title) {
            HStack {
                Text(path)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button(ClaudeSettingsText.choose) {
                    if let url = FolderPicker.choose(prompt: ClaudeSettingsText.chooseFolderPrompt) {
                        onChoose(url)
                    }
                }
            }
        }
    }

    private var clonesHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(ClaudeSettingsText.clonesHeader)
                hint(String(format: ClaudeSettingsText.clonesHint, store.settings.clonesRoot))
            }
            Spacer()
            if store.isScanning {
                ProgressView().controlSize(.small)
            }
            Button(ClaudeSettingsText.rescan) {
                Task { await store.rescan() }
            }
            .disabled(store.isScanning)
        }
    }

    @ViewBuilder
    private var clonesList: some View {
        let repositories = Set(store.scanned.keys).union(store.settings.cloneOverrides.keys).sorted()
        if repositories.isEmpty {
            Text(store.isScanning ? ClaudeSettingsText.scanning : ClaudeSettingsText.noClones)
                .foregroundStyle(.secondary)
        }
        ForEach(repositories, id: \.self) { repository in
            HStack {
                Text(repository)
                Text(ClaudeSettingsText.arrow).foregroundStyle(.secondary)
                Text(path(for: repository))
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button(ClaudeSettingsText.changePath) {
                    if let url = FolderPicker.choose(prompt: ClaudeSettingsText.chooseFolderPrompt) {
                        store.setOverride(repository: repository, path: url)
                    }
                }
            }
        }
        Button(ClaudeSettingsText.addManually) { addManually() }
        if let manualError {
            Text(manualError).font(.system(size: ClaudeSettingsMetrics.hintSize)).foregroundStyle(.red)
        }
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
                manualError = ClaudeSettingsText.notGitHubRepository
                return
            }
            store.setOverride(repository: repository, path: url)
        }
    }

    private var terminalChoice: Binding<TerminalChoice> {
        Binding(
            get: { TerminalChoice(store.settings.terminal) },
            set: { choice in
                rememberCustomTemplate(currentCustomTemplate)
                switch choice {
                case .ghostty: store.settings.terminal = .ghostty
                case .terminal: store.settings.terminal = .terminal
                case .iterm: store.settings.terminal = .iterm
                case .custom: store.settings.terminal = .custom(template: lastCustomTemplate)
                }
            }
        )
    }

    private var currentCustomTemplate: String {
        if case .custom(let template) = store.settings.terminal { return template }
        return ""
    }

    private var customTemplate: Binding<String> {
        Binding(
            get: { currentCustomTemplate },
            set: {
                rememberCustomTemplate($0)
                store.settings.terminal = .custom(template: $0)
            }
        )
    }

    private func rememberCustomTemplate(_ template: String) {
        if !template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lastCustomTemplate = template
        }
    }
}
