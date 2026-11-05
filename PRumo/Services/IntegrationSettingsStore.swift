import Foundation
import Observation
import PRumoKit

@Observable @MainActor
final class IntegrationSettingsStore {
    var jira: JiraSettings {
        didSet { persist() }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        jira = defaults.data(forKey: AppConstants.jiraSettingsKey)
            .flatMap { try? JSONDecoder().decode(JiraSettings.self, from: $0) } ?? .defaults
    }

    func link(for pr: PullRequest) -> JiraLink? {
        jira.link(for: pr)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(jira) else { return }
        defaults.set(data, forKey: AppConstants.jiraSettingsKey)
    }
}
