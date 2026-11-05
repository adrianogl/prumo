import PRumoKit

struct AccountSession: Sendable {
    let account: Account
    let credential: SessionCredential
    let coordinator: RefreshCoordinator
    let gate: SessionGate

    var token: String { credential.token }
    var client: any AccountClient { credential.client }

    func with(account: Account) -> AccountSession {
        AccountSession(account: account, credential: credential, coordinator: coordinator, gate: gate)
    }
}
