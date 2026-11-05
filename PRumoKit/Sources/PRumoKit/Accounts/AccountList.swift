import Foundation

public struct AccountList: Codable, Equatable, Sendable {
    public var accounts: [Account]

    public init(accounts: [Account] = []) {
        self.accounts = accounts
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        accounts = c.decodeLossyArray(Account.self, forKey: .accounts)
    }

    public static func decode(_ data: Data?) -> AccountList? {
        guard let data else { return nil }
        return (try? JSONDecoder().decode(AccountList.self, from: data)) ?? AccountList()
    }

    public func encoded() -> Data {
        (try? JSONEncoder().encode(self)) ?? Data()
    }

    @discardableResult
    public mutating func add(_ account: Account) -> Bool {
        guard !accounts.contains(where: { $0.isSameIdentity(as: account) }) else { return false }
        accounts.append(account)
        return true
    }

    public mutating func remove(id: String) {
        accounts.removeAll { $0.id == id }
    }

    public mutating func rename(id: String, nickname: String) {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return }
        accounts[index].nickname = nickname
    }

    public mutating func updateLogin(id: String, login: String) {
        guard let index = accounts.firstIndex(where: { $0.id == id }) else { return }
        accounts[index].login = login
    }

    public func account(id: String) -> Account? {
        accounts.first { $0.id == id }
    }
}
