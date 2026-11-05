public enum AccountMigration {
    public static let legacyAccountID = "github-legacy"

    public static func account(from legacy: LegacyAccountState, existing: AccountList?) -> Account? {
        guard existing == nil, legacy.onboardingDone else { return nil }
        return Account(id: legacyAccountID, login: legacy.login ?? "", origin: legacy.origin ?? .pasted)
    }

    public static func reminders(_ state: ReminderState, migrated: Account) -> ReminderState {
        guard state.initialized, state.viewer == nil || state.viewer == migrated.login else { return state }
        var result = state
        result.baselined = [migrated.id]
        return result
    }
}
