import Foundation
import Observation
import PRumoKit

@Observable @MainActor
final class AddAccountModel {
    var detected: [GhAccount] = []
    var tokenInput = ""
    var nickname = ""
    var errorMessage: String?
    var isValidating = false
    private(set) var isFinished = false
    let reconnecting: Account?

    @ObservationIgnored private let app: AppModel
    @ObservationIgnored private let discovery: GhAccountDiscovery
    @ObservationIgnored private var isCancelled = false

    init(app: AppModel, reconnecting: Account? = nil, discovery: GhAccountDiscovery = .system()) {
        self.app = app
        self.reconnecting = reconnecting
        self.discovery = discovery
    }

    var canConnect: Bool {
        !isValidating && !trimmedToken.isEmpty
    }

    private var trimmedToken: String {
        tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func detect() async {
        guard reconnecting == nil else { return }
        let found = await discovery.accounts()
        let known = app.accounts.list.accounts
        detected = found.filter { gh in
            let candidate = Self.account(from: gh, nickname: "")
            return !known.contains { $0.isSameIdentity(as: candidate) }
        }
    }

    func use(_ account: GhAccount) async {
        guard !isValidating else { return }
        isValidating = true
        errorMessage = nil
        defer { isValidating = false }
        guard let token = await discovery.token(for: account.login) else {
            errorMessage = AccountsSettingsText.ghTokenMissing
            return
        }
        guard await validate(token) != nil, !isCancelled else { return }
        await save(Self.account(from: account, nickname: trimmedNickname), token: token)
    }

    func connectPasted() async -> Bool {
        let token = trimmedToken
        guard !token.isEmpty, !isValidating else { return false }
        isValidating = true
        errorMessage = nil
        defer { isValidating = false }
        guard let login = await validate(token), !isCancelled else { return false }
        guard let reconnecting else {
            let account = Account(
                id: UUID().uuidString.lowercased(), login: login, nickname: trimmedNickname, origin: .pasted)
            return await save(account, token: token)
        }
        guard login.caseInsensitiveCompare(reconnecting.login) == .orderedSame else {
            errorMessage = AccountsSettingsText.otherLogin(login, expected: reconnecting.login)
            return false
        }
        do {
            try await app.replaceToken(id: reconnecting.id, token: token)
        } catch {
            errorMessage = AccountsSettingsText.keychainFailure
            return false
        }
        finish()
        return true
    }

    func cancel() {
        isCancelled = true
        tokenInput = ""
    }

    @discardableResult
    private func save(_ account: Account, token: String) async -> Bool {
        do {
            try await app.addAccount(account, token: token)
        } catch is DuplicateAccountError {
            errorMessage = AccountsSettingsText.duplicate
            return false
        } catch {
            errorMessage = AccountsSettingsText.keychainFailure
            return false
        }
        finish()
        return true
    }

    private func finish() {
        tokenInput = ""
        isFinished = true
    }

    private func validate(_ token: String) async -> String? {
        let client = GitHubClient(token: token)
        let result = await Task.detached { () -> Result<String, GitHubError> in
            do throws(GitHubError) {
                return .success(try await client.viewerLogin())
            } catch {
                return .failure(error)
            }
        }.value
        switch result {
        case .success(let login) where !login.isEmpty:
            return login
        case .success:
            errorMessage = AccountsSettingsText.unavailable
        case .failure(let error):
            errorMessage = Self.message(for: error)
        }
        return nil
    }

    private static func message(for error: GitHubError) -> String {
        switch error {
        case .unauthorized: AccountsSettingsText.invalidToken
        case .network: AccountsSettingsText.noConnection
        default: AccountsSettingsText.unavailable
        }
    }

    private static func account(from gh: GhAccount, nickname: String) -> Account {
        Account(
            id: UUID().uuidString.lowercased(),
            host: GhHostsFile.normalizeHost(gh.host),
            login: gh.login,
            nickname: nickname,
            origin: .ghCLI)
    }
}
