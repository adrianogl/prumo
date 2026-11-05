import Foundation
import Observation
import PRumoKit

enum OnboardingStep {
    case welcome, token, notifications, ready
}

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

    @ObservationIgnored private let app: AppModel
    @ObservationIgnored private var ghToken: String?

    init(app: AppModel) {
        self.app = app
    }

    func detectGh() async {
        isCheckingGh = true
        defer { isCheckingGh = false }
        guard let token = await GhCLITokenSource(runner: SystemProcessRunner()).token() else { return }
        if let snapshot = try? await GitHubClient(token: token).fetchSnapshot() {
            ghToken = token
            ghLogin = snapshot.viewer
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
            if case .network = error {
                errorMessage = OnboardingText.offline
            } else {
                errorMessage = OnboardingText.invalidToken
            }
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
        do {
            try LaunchAtLogin.set(launchAtLogin)
            launchError = nil
        } catch {
            launchError = error.localizedDescription
        }
    }

    private func finishConnection(token: String, origin: TokenOrigin, login: String) {
        do {
            try app.connect(token: token, origin: origin, login: login)
            step = .notifications
        } catch {
            errorMessage = OnboardingText.keychainFailure
        }
    }
}
