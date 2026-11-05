import PRumoKit

struct AccountSession: Sendable {
    let account: Account
    let token: String
    let client: any AccountClient
    let coordinator: RefreshCoordinator
    let gate: SessionGate

    func with(account: Account) -> AccountSession {
        AccountSession(account: account, token: token, client: client, coordinator: coordinator, gate: gate)
    }
}
