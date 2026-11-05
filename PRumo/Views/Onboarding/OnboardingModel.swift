import Foundation
import Observation
import PRumoKit

@Observable @MainActor
final class OnboardingModel {
    var step: OnboardingStep = .welcome
    var isCheckingGh = true
    var ghLogin: String?
    var tokenInput = ""
    var isValidating = false
    var errorMessage: String?
    var launchAtLogin = true
    var launchError: String?
    var ignoreDrafts: Bool

    @ObservationIgnored private let app: AppModel
    @ObservationIgnored private var ghToken: String?

    init(app: AppModel) {
        self.app = app
        ignoreDrafts = app.organization.settings.ignoreDraftsInReview
    }

    func detectGh() async {
        isCheckingGh = true
        defer { isCheckingGh = false }
        guard let token = await GhCLITokenSource(runner: SystemProcessRunner()).token() else { return }
        do {
            let snapshot = try await GitHubClient(token: token).fetchSnapshot()
            ghToken = token
            ghLogin = snapshot.viewer
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func useGh() {
        guard let token = ghToken, let login = ghLogin else { return }
        finishConnection(token: token, origin: .ghCLI, login: login)
    }

    func connectPasted() async {
        let token = tokenInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        isValidating = true
        errorMessage = nil
        defer { isValidating = false }
        do {
            let snapshot = try await GitHubClient(token: token).fetchSnapshot()
            finishConnection(token: token, origin: .pasted, login: snapshot.viewer)
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func requestNotifications() async {
        _ = await app.requestNotificationPermission()
        enterReady()
    }

    func enterReady() {
        step = .ready
        applyLaunchAtLogin()
    }

    func applyLaunchAtLogin() {
        if launchAtLogin != LaunchAtLogin.isEnabled {
            do {
                try LaunchAtLogin.set(launchAtLogin)
            } catch {
                launchError = error.localizedDescription
                launchAtLogin = LaunchAtLogin.isEnabled
                return
            }
        }
        launchError = LaunchAtLogin.approvalMessage(enabled: launchAtLogin)
    }

    func applyIgnoreDrafts() {
        app.organization.settings.ignoreDraftsInReview = ignoreDrafts
    }

    func useOtherToken() {
        errorMessage = nil
        step = .token
    }

    private static func message(for error: ProviderError) -> String {
        switch error {
        case .unauthorized: OnboardingText.invalidToken
        case .network: OnboardingText.offline
        case .unexpectedResponse: OnboardingText.unexpectedResponse
        default: OnboardingText.unavailable
        }
    }

    private func finishConnection(token: String, origin: TokenOrigin, login: String) {
        do {
            try app.connect(token: token, origin: origin, login: login)
            tokenInput = ""
            errorMessage = nil
            step = .notifications
        } catch {
            errorMessage = OnboardingText.keychainFailure
        }
    }
}
