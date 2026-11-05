import SwiftUI
import PRumoKit

struct AccountsSettingsView: View {
    let model: AppModel
    @State private var sheet: AddAccountMode?
    @State private var renaming: Account?
    @State private var nicknameDraft = ""
    @State private var removing: Account?

    var body: some View {
        Form {
            Section(AccountsSettingsText.section) {
                ForEach(model.accounts.list.accounts) { account in
                    AccountRowView(
                        account: account,
                        status: model.accounts.statuses[account.id],
                        onRetry: model.refreshNow,
                        onReconnect: { reconnect(account) },
                        onRename: {
                            nicknameDraft = account.nickname
                            renaming = account
                        },
                        onRemove: { removing = account })
                }
            }
            Section {
                HStack {
                    Button(AccountsSettingsText.add) { sheet = .add }
                        .buttonStyle(PrimaryButtonStyle())
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .sheet(item: $sheet) { mode in
            AddAccountSheet(app: model, reconnecting: mode.account)
        }
        .alert(AccountsSettingsText.renameTitle, isPresented: isPresented($renaming), presenting: renaming) { account in
            TextField(AccountsSettingsText.nickname, text: $nicknameDraft)
            Button(AccountsSettingsText.save) {
                model.renameAccount(id: account.id, nickname: nicknameDraft.trimmingCharacters(in: .whitespacesAndNewlines))
            }
            Button(AccountsSettingsText.cancel, role: .cancel) {}
        }
        .alert(
            removing.map { AccountsSettingsText.removeTitle($0.displayName) } ?? "",
            isPresented: isPresented($removing),
            presenting: removing
        ) { account in
            Button(AccountsSettingsText.removeConfirm, role: .destructive) { model.removeAccount(id: account.id) }
            Button(AccountsSettingsText.cancel, role: .cancel) {}
        } message: { _ in
            Text(AccountsSettingsText.removeMessage)
        }
    }

    private func reconnect(_ account: Account) {
        switch account.origin {
        case .pasted: sheet = .reconnect(account)
        case .ghCLI, .glabCLI: model.reconnect(id: account.id)
        }
    }

    private func isPresented(_ item: Binding<Account?>) -> Binding<Bool> {
        Binding(
            get: { item.wrappedValue != nil },
            set: { if !$0 { item.wrappedValue = nil } })
    }
}
