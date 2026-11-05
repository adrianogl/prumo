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
            if model.reconnecting == nil, !model.detected.isEmpty {
                ForEach(model.detected, id: \.login) { account in
                    detectedRow(account)
                }
                hint(AccountsSettingsText.orPastedToken)
            }
            field(AccountsSettingsText.tokenField) {
                SecureField(AccountsSettingsText.tokenField, text: $model.tokenInput)
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(connect)
            }
            Link(AccountsSettingsText.createToken, destination: AppConstants.tokenCreationURL)
                .font(.system(size: AccountsSettingsMetrics.fieldLabelSize))
            if model.reconnecting == nil {
                field(AccountsSettingsText.nickname) {
                    TextField(AccountsSettingsText.nickname, text: $model.nickname)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                }
            }
            if let message = model.errorMessage {
                Text(message)
                    .font(.system(size: AccountsSettingsMetrics.errorSize))
                    .foregroundStyle(.red)
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
    }

    private func detectedRow(_ account: GhAccount) -> some View {
        HStack(spacing: AccountsSettingsMetrics.detectedSpacing) {
            ProviderIcon(kind: .github, size: AccountsSettingsMetrics.detectedIconSize)
            Text(AccountsSettingsText.foundInGh(login: account.login, host: GhHostsFile.normalizeHost(account.host)))
                .font(.system(size: AccountsSettingsMetrics.detectedTextSize))
            Spacer()
            Button(AccountsSettingsText.use) {
                Task {
                    await model.use(account)
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
