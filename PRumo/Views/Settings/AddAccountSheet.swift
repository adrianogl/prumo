import SwiftUI
import PRumoKit

struct AddAccountSheet: View {
    @State private var model: AddAccountModel
    @Environment(\.dismiss) private var dismiss

    init(app: AppModel, reconnecting: Account?) {
        _model = State(initialValue: AddAccountModel(app: app, reconnecting: reconnecting))
    }

    private var title: String {
        model.reconnecting.map { AccountsSettingsText.reconnectTitle($0.displayName) } ?? AccountsSettingsText.sheetTitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AccountsSettingsMetrics.sheetSpacing) {
            Text(title).font(.headline)
            if model.reconnecting == nil {
                Picker(AccountsSettingsText.sheetTitle, selection: $model.provider) {
                    ForEach(AddAccountOptions.providers, id: \.self) { provider in
                        Text(AccountsSettingsText.providerName(provider)).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            switch model.provider {
            case .github: gitHubForm
            case .gitlab: gitLabForm
            }
            if let message = model.errorMessage {
                Text(message)
                    .font(.system(size: AccountsSettingsMetrics.errorSize))
                    .foregroundStyle(Color.statusBad)
            }
            HStack(spacing: AccountsSettingsMetrics.buttonSpacing) {
                Spacer()
                if model.isValidating { ProgressView().controlSize(.small) }
                Button(AccountsSettingsText.cancel) {
                    model.cancel()
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button(AccountsSettingsText.connect, action: connect)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!model.canConnect)
            }
        }
        .padding(AccountsSettingsMetrics.sheetPadding)
        .frame(width: AccountsSettingsMetrics.sheetWidth)
        .task { await model.detect() }
        .onChange(of: model.provider) { model.errorMessage = nil }
    }

    @ViewBuilder
    private var gitHubForm: some View {
        if model.reconnecting == nil, !model.detected.isEmpty {
            ForEach(model.detected, id: \.login) { account in
                detectedRow(
                    kind: .github,
                    text: AccountsSettingsText.foundInGh(
                        login: account.login, host: GhHostsFile.normalizeHost(account.host))
                ) { await model.use(account) }
            }
            hint(AccountsSettingsText.orPastedToken)
        }
        tokenField(AccountsSettingsText.tokenField)
        Link(AccountsSettingsText.createToken, destination: AppConstants.tokenCreationURL)
            .font(.system(size: AccountsSettingsMetrics.fieldLabelSize))
        nicknameField
    }

    @ViewBuilder
    private var gitLabForm: some View {
        if model.reconnecting == nil, !model.detectedGlab.isEmpty {
            ForEach(model.detectedGlab, id: \.host) { account in
                detectedRow(
                    kind: .gitlab,
                    text: AccountsSettingsText.foundInGlab(login: account.login ?? "", host: account.host)
                ) { await model.use(account) }
            }
            hint(AccountsSettingsText.orPastedToken)
        }
        if model.reconnecting == nil {
            field(AccountsSettingsText.address) {
                TextField(AccountsSettingsText.address, text: $model.address, prompt: Text(AccountsSettingsText.addressPlaceholder))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
            }
        }
        tokenField(AccountsSettingsText.gitLabTokenField)
        nicknameField
        Link(AccountsSettingsText.createGitLabToken, destination: model.gitLabTokenURL)
            .font(.system(size: AccountsSettingsMetrics.fieldLabelSize))
    }

    private func tokenField(_ label: String) -> some View {
        field(label) {
            SecureField(label, text: $model.tokenInput)
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .onSubmit(connect)
        }
    }

    @ViewBuilder
    private var nicknameField: some View {
        if model.reconnecting == nil {
            field(AccountsSettingsText.nickname) {
                TextField(AccountsSettingsText.nickname, text: $model.nickname)
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func detectedRow(kind: ProviderKind, text: String, use: @escaping () async -> Void) -> some View {
        HStack(spacing: AccountsSettingsMetrics.detectedSpacing) {
            ProviderIcon(kind: kind, size: AccountsSettingsMetrics.detectedIconSize)
            Text(text)
                .font(.system(size: AccountsSettingsMetrics.detectedTextSize))
            Spacer()
            Button(AccountsSettingsText.use) {
                Task {
                    await use()
                    if model.isFinished { dismiss() }
                }
            }
            .disabled(model.isValidating)
        }
        .padding(AccountsSettingsMetrics.detectedPadding)
        .overlay(
            RoundedRectangle(cornerRadius: AccountsSettingsMetrics.detectedCornerRadius)
                .strokeBorder(.separator))
    }

    private func field(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: AccountsSettingsMetrics.fieldSpacing) {
            hint(label)
            content()
        }
    }

    private func hint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: AccountsSettingsMetrics.fieldLabelSize))
            .foregroundStyle(.secondary)
    }

    private func connect() {
        guard model.canConnect else { return }
        Task {
            if await model.connectPasted() { dismiss() }
        }
    }
}
