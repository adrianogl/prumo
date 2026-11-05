import Foundation

enum AppConstants {
    static let refreshIntervalKey = "refreshInterval"
    static let defaultRefreshInterval: TimeInterval = 60
    static let notificationURLKey = "url"
    static let accountLoginKey = "accountLogin"
    static let tokenOriginKey = "tokenOrigin"
    static let onboardingDoneKey = "onboardingDone"
    static let claudeSettingsKey = "claudeSettings"
    static let jiraSettingsKey = "jiraSettings"
    static let ghTokenRetryAttempts = 3
    static let ghTokenRetryDelay: Duration = .seconds(2)
    static let longCommandTimeout: Duration = .seconds(300)
    static let keychainService = "dev.aglv.prumo"
    static let keychainAccount = "github-token"
    static let launchApprovalMessage = "Aprove em Ajustes do Sistema > Itens de Início"
    static let refreshIntervalOptions: [(label: String, seconds: TimeInterval)] = [
        ("30 s", 30), ("60 s", 60), ("2 min", 120), ("5 min", 300)
    ]
    static let tokenCreationURL = URL(string: "https://github.com/settings/tokens/new?scopes=repo,read:org&description=PRumo")!
    static let licenseURL = URL(string: "https://www.apache.org/licenses/LICENSE-2.0")!
}
