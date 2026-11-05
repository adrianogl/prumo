import Foundation
import Observation
import PRumoKit

@Observable @MainActor
final class AppModel {
    var snapshot: Snapshot?
    var connection: ConnectionState = .ok
    var lastRefresh: Date?
    var nextRefresh: Date?
    var needsOnboarding = false
    var login: String?
    var origin: TokenOrigin?
    let claude: ClaudeSettingsStore

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
        defaults: UserDefaults = .standard,
        claude: ClaudeSettingsStore? = nil
    ) {
        self.notifications = notifications
        self.tokenStore = tokenStore
        self.snapshotStore = snapshotStore
        self.defaults = defaults
        self.claude = claude ?? ClaudeSettingsStore(defaults: defaults)
        login = defaults.string(forKey: AppConstants.accountLoginKey)
        origin = defaults.string(forKey: AppConstants.tokenOriginKey).flatMap(TokenOrigin.init(rawValue:))
    }

    private var refreshInterval: TimeInterval {
        let stored = defaults.double(forKey: AppConstants.refreshIntervalKey)
        return stored > 0 ? stored : AppConstants.defaultRefreshInterval
    }

    func start() {
        Task { await claude.rescan() }
        startupTask?.cancel()
        startupTask = Task {
            let resolver = TokenResolver(store: tokenStore, gh: GhCLITokenSource(runner: SystemProcessRunner()))
            let onboarded = defaults.bool(forKey: AppConstants.onboardingDoneKey)
            var resolved = await resolver.resolve()
            if resolved == nil, onboarded, origin == .ghCLI {
                for _ in 0..<AppConstants.ghTokenRetryAttempts {
                    try? await Task.sleep(for: AppConstants.ghTokenRetryDelay)
                    guard !Task.isCancelled else { return }
                    resolved = await resolver.resolve()
                    if resolved != nil { break }
                }
            }
            guard !Task.isCancelled else { return }
            guard let resolved, resolved.origin == .pasted || onboarded else {
                needsOnboarding = true
                return
            }
            needsOnboarding = false
            if origin != resolved.origin {
                origin = resolved.origin
                defaults.set(resolved.origin.rawValue, forKey: AppConstants.tokenOriginKey)
            }
            defaults.set(true, forKey: AppConstants.onboardingDoneKey)
            let notifications = notifications
            Task.detached { _ = await notifications.requestAuthorization() }
            await begin(token: resolved.token)
        }
    }

    func connect(token: String, origin: TokenOrigin, login: String) throws {
        if origin == .pasted {
            try tokenStore.write(token)
        } else {
            try tokenStore.delete()
        }
        startupTask?.cancel()
        self.login = login
        self.origin = origin
        defaults.set(login, forKey: AppConstants.accountLoginKey)
        defaults.set(origin.rawValue, forKey: AppConstants.tokenOriginKey)
        defaults.set(true, forKey: AppConstants.onboardingDoneKey)
        needsOnboarding = false
        connection = .ok
        startupTask = Task { await begin(token: token) }
    }

    func requestNotificationPermission() async -> Bool {
        await notifications.requestAuthorization()
    }

    private func begin(token: String) async {
        let client = GitHubClient(token: token)
        coordinator = RefreshCoordinator(
            fetch: { () async throws(GitHubError) -> Snapshot in try await client.fetchSnapshot() },
            store: snapshotStore
        )
        let stored = await snapshotStore.load()
        guard !Task.isCancelled else { return }
        snapshot = stored
        startPolling()
    }

    func refreshNow() {
        guard !needsOnboarding else { return }
        if pollingTask == nil {
            start()
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
        login = nil
        origin = nil
        defaults.removeObject(forKey: AppConstants.accountLoginKey)
        defaults.removeObject(forKey: AppConstants.tokenOriginKey)
        defaults.set(false, forKey: AppConstants.onboardingDoneKey)
        needsOnboarding = true
    }

    private func startPolling() {
        stopPolling()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let shouldContinue = await self.runRefresh()
                guard shouldContinue else {
                    if !Task.isCancelled { self.pollingTask = nil }
                    return
                }
                let interval = self.refreshInterval
                self.nextRefresh = Date.now.addingTimeInterval(interval)
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
        if let viewer = result.snapshot?.viewer, viewer != login {
            login = viewer
            defaults.set(viewer, forKey: AppConstants.accountLoginKey)
        }
        connection = result.state
        if result.state == .ok { lastRefresh = .now }
        notifications.post(result.events)
        return result.state != .unauthorized
    }
}
