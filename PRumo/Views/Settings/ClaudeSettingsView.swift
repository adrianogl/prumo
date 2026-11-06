import SwiftUI
import PRumoKit

struct ClaudeSettingsView: View {
    let store: ClaudeSettingsStore
    let relevant: Set<String>
    @State private var showsClonesManager = false
    @State private var lastCustomTemplate = ""
    @State private var provider = ProviderKind.github

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                Picker(ClaudeSettingsText.provider, selection: $provider) {
                    ForEach(AddAccountOptions.providers, id: \.self) { provider in
                        Text(AccountsSettingsText.providerName(provider)).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                providerTemplateFields
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
                clonesSummary
            }
            Section {
                Toggle(ClaudeSettingsText.removeWorktree, isOn: $store.settings.removeWorktreeOnClose)
            }
        }
        .formStyle(.grouped)
        .task { await store.rescan() }
        .sheet(isPresented: $showsClonesManager) {
            ClonesManagerView(store: store, relevant: relevant)
        }
    }

    @ViewBuilder
    private var providerTemplateFields: some View {
        @Bindable var store = store
        switch provider {
        case .github:
            templateField(ClaudeSettingsText.reviewTemplate, hint: ClaudeSettingsText.reviewVariables, text: $store.settings.reviewTemplate)
            templateField(ClaudeSettingsText.ciTemplate, hint: ClaudeSettingsText.ciVariables, text: $store.settings.ciTemplate)
            templateField(ClaudeSettingsText.conflictTemplate, hint: ClaudeSettingsText.conflictVariables, text: $store.settings.conflictTemplate)
            templateField(ClaudeSettingsText.commentsTemplate, hint: ClaudeSettingsText.commentsVariables, text: $store.settings.commentsTemplate)
        case .gitlab:
            templateField(ClaudeSettingsText.gitlabReviewTemplate, hint: ClaudeSettingsText.reviewVariables, text: $store.settings.gitlabReviewTemplate)
            templateField(ClaudeSettingsText.gitlabCiTemplate, hint: ClaudeSettingsText.gitlabCiVariables, text: $store.settings.gitlabCiTemplate)
            templateField(ClaudeSettingsText.conflictTemplate, hint: ClaudeSettingsText.conflictVariables, text: $store.settings.gitlabConflictTemplate)
            templateField(ClaudeSettingsText.commentsTemplate, hint: ClaudeSettingsText.commentsVariables, text: $store.settings.gitlabCommentsTemplate)
        }
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
                    .foregroundStyle(Color.statusBad)
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

    private var clonesSummary: some View {
        LabeledContent(ClaudeSettingsText.clones) {
            HStack {
                if store.isScanning {
                    ProgressView().controlSize(.small)
                    Text(ClaudeSettingsText.scanningClones).foregroundStyle(.secondary)
                } else if store.repositories.isEmpty {
                    Text(ClaudeSettingsText.noClones).foregroundStyle(.secondary)
                } else {
                    Text(clonesSummaryText).foregroundStyle(.secondary)
                }
                Button(ClaudeSettingsText.manageClones) { showsClonesManager = true }
            }
        }
    }

    private var clonesSummaryText: String {
        String(
            format: ClaudeSettingsText.clonesSummary,
            store.repositories.count, store.settings.clonesRoot, store.resolvedCount(of: relevant))
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
