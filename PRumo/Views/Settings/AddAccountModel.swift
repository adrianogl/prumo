import Foundation
import Observation
import PRumoKit

@Observable @MainActor
final class AddAccountModel {
    var provider: ProviderKind
    var address: String
    var detected: [GhAccount] = []
    var detectedGlab: [GlabAccount] = []
    var tokenInput = ""
    var nickname = ""
    var errorMessage: String?
    var isValidating = false
    private(set) var isFinished = false
    let reconnecting: Account?

    @ObservationIgnored private let app: AppModel
    @ObservationIgnored private let discovery: GhAccountDiscovery
    @ObservationIgnored private let glabDiscovery: GlabAccountDiscovery
    @ObservationIgnored private var isCancelled = false

    init(
        app: AppModel,
        reconnecting: Account? = nil,
        discovery: GhAccountDiscovery = .system(),
        glabDiscovery: GlabAccountDiscovery = .system()
    ) {
        self.app = app
        self.reconnecting = reconnecting
        self.discovery = discovery
        self.glabDiscovery = glabDiscovery
        provider = reconnecting?.provider ?? .github
        address = reconnecting?.provider == .gitlab ? reconnecting?.host ?? "" : ""
    }

    var canConnect: Bool {
        !isValidating && !trimmedToken.isEmpty
    }

    var gitLabTokenURL: URL {
        let host = (try? GitLabAddress.normalize(address).get()) ?? GitLabAddress.defaultHost
        return GitLabAddress.tokenCreationURL(host: host)
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
        detected = found.filter { !isKnown(Self.account(from: $0, nickname: "")) }
        var glab: [GlabAccount] = []
        for account in await glabDiscovery.accounts() {
            guard let resolved = await withLogin(account) else { continue }
            let candidate = Account(
                id: "", provider: .gitlab, host: resolved.host, login: resolved.login ?? "", origin: .glabCLI)
            if !isKnown(candidate) { glab.append(resolved) }
        }
        detectedGlab = glab
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
        guard await validate(token, provider: .github, host: AccountConstants.githubHost) != nil, !isCancelled else {
            return
        }
        await save(Self.account(from: account, nickname: trimmedNickname), token: token)
    }

    func use(_ account: GlabAccount) async {
        guard !isValidating else { return }
        isValidating = true
        errorMessage = nil
        defer { isValidating = false }
        guard let token = await glabDiscovery.token(host: account.host) else {
            errorMessage = AccountsSettingsText.glabTokenMissing
            return
        }
        guard let identity = await validate(token, provider: .gitlab, host: account.host), !isCancelled else { return }
        let added = Account(
            id: UUID().uuidString.lowercased(),
            provider: .gitlab,
            host: account.host,
            login: identity.login,
            nickname: trimmedNickname,
            origin: .glabCLI,
            scopes: identity.scopes)
        await save(added, token: token)
    }

    func connectPasted() async -> Bool {
        let token = trimmedToken
        guard !token.isEmpty, !isValidating else { return false }
        errorMessage = nil
        guard let host = targetHost() else { return false }
        isValidating = true
        defer { isValidating = false }
        guard let identity = await validate(token, provider: provider, host: host), !isCancelled else { return false }
        guard let reconnecting else {
            let account = Account(
                id: UUID().uuidString.lowercased(),
                provider: provider,
                host: host,
                login: identity.login,
                nickname: trimmedNickname,
                origin: .pasted,
                scopes: identity.scopes)
            return await save(account, token: token)
        }
        guard identity.login.caseInsensitiveCompare(reconnecting.login) == .orderedSame else {
            errorMessage = AccountsSettingsText.otherLogin(identity.login, expected: reconnecting.login)
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

    private func targetHost() -> String? {
        if let reconnecting { return reconnecting.host }
        guard provider == .gitlab else { return AccountConstants.githubHost }
        switch GitLabAddress.normalize(address) {
        case .success(let host):
            return host
        case .failure(let error):
            errorMessage = Self.message(for: error)
            return nil
        }
    }

    private func isKnown(_ candidate: Account) -> Bool {
        app.accounts.list.accounts.contains { $0.isSameIdentity(as: candidate) }
    }

    private func withLogin(_ account: GlabAccount) async -> GlabAccount? {
        if account.login?.isEmpty == false { return account }
        guard let token = await glabDiscovery.token(host: account.host) else { return nil }
        let client = GitLabClient(host: account.host, token: token)
        let login = await Task.detached { () -> String? in
            try? await client.currentUsername()
        }.value
        guard let login, !login.isEmpty else { return nil }
        return GlabAccount(host: account.host, login: login, isOAuth: account.isOAuth, expiresAt: account.expiresAt)
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

    private func validate(
        _ token: String, provider: ProviderKind, host: String
    ) async -> (login: String, scopes: [String]?)? {
        let result = await Task.detached { () -> Result<(login: String, scopes: [String]?), ProviderError> in
            do throws(ProviderError) {
                switch provider {
                case .github:
                    return .success((try await GitHubClient(token: token).viewerLogin(), nil))
                case .gitlab:
                    let client = GitLabClient(host: host, token: token)
                    let login = try await client.currentUsername()
                    return .success((login, await client.tokenScopes()))
                }
            } catch {
                return .failure(error)
            }
        }.value
        switch result {
        case .success(let identity) where !identity.login.isEmpty:
            return identity
        case .success:
            errorMessage = Self.unavailable(provider)
        case .failure(let error):
            errorMessage = Self.message(for: error, provider: provider, host: host)
        }
        return nil
    }

    private static func unavailable(_ provider: ProviderKind) -> String {
        switch provider {
        case .github: AccountsSettingsText.unavailable
        case .gitlab: AccountsSettingsText.gitLabUnavailable
        }
    }

    private static func message(for error: ProviderError, provider: ProviderKind, host: String) -> String {
        switch (provider, error) {
        case (.github, .unauthorized): AccountsSettingsText.invalidToken
        case (.github, .network): AccountsSettingsText.noConnection
        case (.gitlab, .unauthorized): AccountsSettingsText.gitLabInvalidToken
        case (.gitlab, .network): AccountsSettingsText.gitLabNoAccess(host)
        default: unavailable(provider)
        }
    }

    private static func message(for error: GitLabAddressError) -> String {
        switch error {
        case .insecure: AccountsSettingsText.insecureAddress
        case .invalid: AccountsSettingsText.invalidAddress
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
