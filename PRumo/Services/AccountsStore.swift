import Foundation
import Observation
import PRumoKit

@Observable @MainActor
final class AccountsStore {
    var list: AccountList
    var statuses: [String: AccountStatus] = [:]
    @ObservationIgnored private(set) var hasStoredList: Bool

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var unreadable: Data?

    init(defaults: UserDefaults) {
        self.defaults = defaults
        let stored = defaults.string(forKey: AppConstants.accountsKey).map { Data($0.utf8) }
            ?? defaults.data(forKey: AppConstants.accountsKey)
        let decoded = AccountList.decode(stored)
        list = decoded ?? AccountList()
        hasStoredList = decoded != nil
        unreadable = decoded == nil ? stored : nil
    }

    func save() {
        if let unreadable {
            backUp(unreadable)
            self.unreadable = nil
        }
        defaults.set(String(decoding: list.encoded(), as: UTF8.self), forKey: AppConstants.accountsKey)
        hasStoredList = true
    }

    func clear() {
        list = AccountList()
        statuses = [:]
        defaults.removeObject(forKey: AppConstants.accountsKey)
        hasStoredList = false
    }

    private func backUp(_ data: Data) {
        let folder = SnapshotStore.defaultURL().deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(
            to: folder.appending(path: AppConstants.accountsCorruptFileName, directoryHint: .notDirectory),
            options: .atomic)
    }
}
