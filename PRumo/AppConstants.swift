import Foundation

enum AppConstants {
    static let refreshIntervalKey = "refreshInterval"
    static let defaultRefreshInterval: TimeInterval = 60
    static let marksPruneInterval: TimeInterval = 3600
    static let notificationURLKey = "url"
    static let accountLoginKey = "accountLogin"
    static let tokenOriginKey = "tokenOrigin"
    static let onboardingDoneKey = "onboardingDone"
    static let accountsKey = "accounts"
    static let accountsCorruptFileName = "accounts.corrupt.json"
    static let claudeSettingsKey = "claudeSettings"
    static let jiraSettingsKey = "jiraSettings"
    static let organizationKey = "organization"
    static let notificationPreferencesKey = "notificationPreferences"
    static let unseenActivityKey = "unseenActivity"
    static let organizationTeamDefaultMigratedKey = "organizationTeamDefaultMigrated"
    static let hotKeyKey = "globalHotKey"
    static let openWindowAtLaunchKey = "openWindowAtLaunch"
    static let updateAutoCheckKey = "updateAutoCheck"
    static let updateLastCheckKey = "updateLastCheck"
    static let updateNotifiedVersionKey = "updateNotifiedVersion"
    static let updateCheckInterval: Duration = .seconds(24 * 3600)
    static let updateCommandTimeout: Duration = .seconds(120)
    static let updateWorkDirectoryPrefix = "PRumoUpdate-"
    static let shortVersionInfoKey = "CFBundleShortVersionString"
    static let hotKeySignature: UInt32 = 0x5052_6D6F
    static let hotKeyID: UInt32 = 1
    static let statusBarWindowClass = "NSStatusBarWindow"
    static let ghTokenRetryAttempts = 3
    static let ghActiveLoginMinInterval: TimeInterval = 60
    static let ghTokenRetryDelay: Duration = .seconds(2)
    static let longCommandTimeout: Duration = .seconds(300)
    static let secondsPerHour: TimeInterval = 3600
    static let widgetRenewAfter: TimeInterval = 30 * 60
    static let keychainService = "dev.aglv.prumo"
    static let keychainAccount = "github-token"
    static let launchApprovalMessage = "Aprove em Ajustes do Sistema > Itens de Início"
    static let refreshIntervalOptions: [(label: String, seconds: TimeInterval)] = [
        ("30 s", 30), ("60 s", 60), ("2 min", 120), ("5 min", 300)
    ]
    static let stuckCIThresholdOptions: [(label: String, seconds: TimeInterval)] = [
        ("15 min", 15 * 60), ("30 min", 30 * 60), ("1 h", 3600), ("2 h", 2 * 3600)
    ]
    static let tokenCreationURL = URL(string: "https://github.com/settings/tokens/new?scopes=repo,read:org&description=PRumo")!
    static let licenseURL = URL(string: "https://www.apache.org/licenses/LICENSE-2.0")!
}
