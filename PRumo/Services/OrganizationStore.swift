import Foundation
import Observation
import PRumoKit

@Observable @MainActor
final class OrganizationStore {
    var settings: OrganizationSettings {
        didSet { persistSettings() }
    }
    private(set) var unseen: Set<String> {
        didSet { persistUnseen() }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        settings = defaults.data(forKey: AppConstants.organizationKey)
            .flatMap { try? JSONDecoder().decode(OrganizationSettings.self, from: $0) } ?? .defaults
        unseen = Set(defaults.stringArray(forKey: AppConstants.unseenActivityKey) ?? [])
        migrateTeamDefault()
    }

    private func migrateTeamDefault() {
        guard defaults.object(forKey: AppConstants.organizationTeamDefaultMigratedKey) == nil else { return }
        defaults.set(true, forKey: AppConstants.organizationTeamDefaultMigratedKey)
        guard !settings.includeTeamRequests else { return }
        settings.includeTeamRequests = true
    }

    func togglePin(_ pr: PullRequest) {
        if settings.marks.pinned.contains(pr.id) {
            settings.marks.pinned.remove(pr.id)
        } else {
            settings.marks.pinned.insert(pr.id)
        }
    }

    func toggleMute(_ pr: PullRequest, now: Date) {
        if settings.marks.isMuted(pr.id) {
            unmute(id: pr.id)
        } else {
            settings.marks.muted[pr.id] = MutedPullRequest(
                id: pr.id, number: pr.number, title: pr.title, repository: pr.repository, mutedAt: now)
        }
    }

    func unmute(id: String) {
        guard settings.marks.isMuted(id) else { return }
        settings.marks.muted.removeValue(forKey: id)
    }

    func recordActivity(_ ids: Set<String>) {
        guard !ids.isSubset(of: unseen) else { return }
        unseen.formUnion(ids)
    }

    func markSeen(_ ids: Set<String>) {
        guard !unseen.isDisjoint(with: ids) else { return }
        unseen.subtract(ids)
    }

    func pruneActivity(snapshot: Snapshot) {
        let kept = ActivityTracker.pruned(unseen, snapshot: snapshot)
        guard kept != unseen else { return }
        unseen = kept
    }

    func learnRepositories(from snapshot: Snapshot) {
        let found = Set((snapshot.mine + snapshot.toReview).map(\.repository))
        guard !found.isSubset(of: settings.knownRepositories) else { return }
        settings.knownRepositories.formUnion(found)
    }

    private func persistSettings() {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: AppConstants.organizationKey)
    }

    private func persistUnseen() {
        defaults.set(unseen.sorted(), forKey: AppConstants.unseenActivityKey)
    }
}
