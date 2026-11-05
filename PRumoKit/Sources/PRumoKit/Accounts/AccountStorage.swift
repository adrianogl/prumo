import Foundation

public enum AccountStorage {
    public static func keychainAccount(for accountID: String) -> String {
        accountID == AccountMigration.legacyAccountID
            ? AccountConstants.legacyKeychainAccount
            : AccountConstants.keychainPrefix + accountID
    }

    public static func snapshotURL(for accountID: String) -> URL {
        let legacy = SnapshotStore.defaultURL()
        guard accountID != AccountMigration.legacyAccountID else { return legacy }
        return legacy.deletingLastPathComponent()
            .appending(path: AccountConstants.snapshotsFolder, directoryHint: .isDirectory)
            .appending(path: "\(accountID).json", directoryHint: .notDirectory)
    }
}
