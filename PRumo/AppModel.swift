import Foundation
import Observation
import PRumoKit

@Observable @MainActor
final class AppModel {
    var snapshot: Snapshot?
    var connection: ConnectionState = .ok
    var lastRefresh: Date?
    var needsOnboarding = false

    @ObservationIgnored private let notifications: NotificationService
    @ObservationIgnored private let tokenStore: TokenStore
    @ObservationIgnored private let snapshotStore: SnapshotStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var coordinator: RefreshCoordinator?
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var sleepTask: Task<Void, Never>?
    @ObservationIgnored private var startupTask: Task<Void, Never>?

    init(
        notifications: NotificationService,
        tokenStore: TokenStore = KeychainTokenStore(),
        snapshotStore: SnapshotStore = SnapshotStore(fileURL: SnapshotStore.defaultURL()),
        defaults: UserDefaults = .standard
    ) {
        self.notifications = notifications
        self.tokenStore = tokenStore
        self.snapshotStore = snapshotStore
        self.defaults = defaults
    }

    private var refreshInterval: TimeInterval {
        let stored = defaults.double(forKey: AppConstants.refreshIntervalKey)
        return stored > 0 ? stored : AppConstants.defaultRefreshInterval
    }

    func start() {
        startupTask?.cancel()
        let notifications = notifications
        Task { _ = await notifications.requestAuthorization() }
        startupTask = Task {
            let resolver = TokenResolver(store: tokenStore, gh: GhCLITokenSource(runner: SystemProcessRunner()))
            let resolved = await resolver.resolve()
            guard !Task.isCancelled else { return }
            guard let resolved else {
                needsOnboarding = true
                return
            }
            needsOnboarding = false
            let client = GitHubClient(token: resolved.token)
            coordinator = RefreshCoordinator(
                fetch: { () async throws(GitHubError) -> Snapshot in try await client.fetchSnapshot() },
                store: snapshotStore
            )
            let stored = await snapshotStore.load()
            guard !Task.isCancelled else { return }
            snapshot = stored
            startPolling()
        }
    }

    func refreshNow() {
        guard coordinator != nil else { return }
        if pollingTask == nil {
            startPolling()
        } else {
            sleepTask?.cancel()
        }
    }

    func signOut() {
        startupTask?.cancel()
        startupTask = nil
        let stopping = pollingTask
        stopPolling()
        try? tokenStore.delete()
        let store = snapshotStore
        Task {
            await stopping?.value
            await store.delete()
        }
        coordinator = nil
        snapshot = nil
        lastRefresh = nil
        connection = .ok
        needsOnboarding = true
    }

    private func startPolling() {
        stopPolling()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let shouldContinue = await self.runRefresh()
                guard shouldContinue else { return }
                let interval = self.refreshInterval
                let sleeper = Task<Void, Never> { try? await Task.sleep(for: .seconds(interval)) }
                self.sleepTask = sleeper
                await sleeper.value
            }
        }
    }

    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        sleepTask?.cancel()
        sleepTask = nil
    }

    private func runRefresh() async -> Bool {
        guard let coordinator else { return false }
        let result = await coordinator.refresh()
        guard !Task.isCancelled else { return false }
        snapshot = result.snapshot
        connection = result.state
        if result.state == .ok { lastRefresh = .now }
        notifications.post(result.events)
        return result.state != .unauthorized
    }
}
