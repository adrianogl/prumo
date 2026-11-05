import AppKit
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
    let integrations: IntegrationSettingsStore
    let organization: OrganizationStore
    private(set) var launching: Set<String> = []
    private(set) var rerunning: Set<String> = []

    @ObservationIgnored private let notifications: NotificationService
    @ObservationIgnored private let tokenStore: TokenStore
    @ObservationIgnored private let snapshotStore: SnapshotStore
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let worktreeRegistry: WorktreeRegistry
    @ObservationIgnored private var cleaningWorktrees = false
    @ObservationIgnored private var activityBaseline: Snapshot?
    @ObservationIgnored private var githubClient: GitHubClient?
    @ObservationIgnored private var coordinator: RefreshCoordinator?
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var sleepTask: Task<Void, Never>?
    @ObservationIgnored private var startupTask: Task<Void, Never>?

    init(
        notifications: NotificationService,
        tokenStore: TokenStore = KeychainTokenStore(),
        snapshotStore: SnapshotStore = SnapshotStore(fileURL: SnapshotStore.defaultURL()),
        defaults: UserDefaults = .standard,
        claude: ClaudeSettingsStore? = nil,
        integrations: IntegrationSettingsStore? = nil,
        organization: OrganizationStore? = nil,
        worktreeRegistry: WorktreeRegistry = WorktreeRegistry(fileURL: WorktreeRegistry.defaultURL())
    ) {
        self.worktreeRegistry = worktreeRegistry
        self.notifications = notifications
        self.tokenStore = tokenStore
        self.snapshotStore = snapshotStore
        self.defaults = defaults
        self.claude = claude ?? ClaudeSettingsStore(defaults: defaults)
        self.integrations = integrations ?? IntegrationSettingsStore(defaults: defaults)
        self.organization = organization ?? OrganizationStore(defaults: defaults)
        login = defaults.string(forKey: AppConstants.accountLoginKey)
        origin = defaults.string(forKey: AppConstants.tokenOriginKey).flatMap(TokenOrigin.init(rawValue:))
        notifications.onFixWithClaude = { [weak self] id, url in
            guard let self, let pr = self.snapshot?.mine.first(where: { $0.id == id }) else {
                NSWorkspace.shared.open(url)
                return
            }
            self.launchClaude(pr: pr, purpose: .fixCI)
        }
        notifications.onRerun = { [weak self] id, url in
            guard let self,
                  let pr = self.snapshot?.mine.first(where: { $0.id == id }),
                  let runID = pr.failedRunID
            else {
                NSWorkspace.shared.open(url)
                return
            }
            self.rerunFailedJobs(pr: pr, runID: runID)
        }
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
        githubClient = client
        activityBaseline = nil
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
        githubClient = nil
        activityBaseline = nil
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
        let options = TransitionOptions(
            ignoreDraftReviews: organization.settings.ignoreDraftsInReview,
            includeTeamRequests: organization.settings.includeTeamRequests
        )
        let result = await coordinator.refresh(options: options)
        guard !Task.isCancelled else { return false }
        snapshot = result.snapshot
        if let viewer = result.snapshot?.viewer, viewer != login {
            login = viewer
            defaults.set(viewer, forKey: AppConstants.accountLoginKey)
        }
        connection = result.state
        if result.state == .ok { lastRefresh = .now }
        if result.state == .ok, let fresh = result.snapshot {
            trackActivity(fresh: fresh, events: result.events)
            organization.learnRepositories(from: fresh)
            cleanUpWorktrees(snapshot: fresh)
        }
        let marks = organization.settings.marks
        notifications.post(result.events.filter { !marks.isMuted($0.pullRequestID) })
        return result.state != .unauthorized
    }

    private func trackActivity(fresh: Snapshot, events: [NotificationEvent]) {
        let baseline = activityBaseline.flatMap { $0.viewer == fresh.viewer ? $0 : nil }
        let marks = organization.settings.marks
        let touched = ActivityTracker.touched(old: baseline, new: fresh, events: events)
        organization.recordActivity(touched.filter { !marks.isMuted($0) })
        organization.pruneActivity(snapshot: fresh)
        activityBaseline = fresh
    }

    func perform(_ entry: RowMenuEntry, on pr: PullRequest) {
        switch entry {
        case .claude(let purpose, _):
            launchClaude(pr: pr, purpose: purpose)
        case .openInBrowser:
            NSWorkspace.shared.open(pr.url)
        case .openJira(_, let url):
            NSWorkspace.shared.open(url)
        case .rerunFailedJobs(_, let runID):
            rerunFailedJobs(pr: pr, runID: runID)
        case .copyLink:
            copyToPasteboard(pr.url.absoluteString)
        case .copyCheckout(let command):
            copyToPasteboard(command)
        case .separator:
            break
        }
    }

    func isRerunning(_ pr: PullRequest) -> Bool {
        rerunning.contains(pr.id)
    }

    func rerunFailedJobs(pr: PullRequest, runID: Int) {
        guard !rerunning.contains(pr.id), let client = githubClient else { return }
        rerunning.insert(pr.id)
        let repository = pr.repository
        Task {
            let failure = await Task.detached { () -> GitHubError? in
                do throws(GitHubError) {
                    try await client.rerunFailedJobs(repository: repository, runID: runID)
                    return nil
                } catch {
                    return error
                }
            }.value
            rerunning.remove(pr.id)
            if let failure {
                showAlert(
                    RowMenuText.rerunFailure(failure, repository: repository, runID: runID),
                    title: RowMenuText.rerunAlertTitle)
            } else {
                refreshNow()
            }
        }
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func isLaunching(_ pr: PullRequest) -> Bool {
        launching.contains(pr.id)
    }

    func launchClaude(pr: PullRequest, purpose: SessionPurpose) {
        guard !launching.contains(pr.id) else { return }
        if case .custom(let template) = claude.settings.terminal,
           template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            showAlert(ClaudeText.customTerminalEmpty)
            return
        }
        launching.insert(pr.id)
        Task {
            await runLaunch(pr: pr, purpose: purpose, mayAskForClone: true, rescanned: false)
            launching.remove(pr.id)
        }
    }

    private func runLaunch(pr: PullRequest, purpose: SessionPurpose, mayAskForClone: Bool, rescanned: Bool) async {
        let launcher = ClaudeLauncher(
            settings: claude.settings, scanned: claude.scanned,
            runner: SystemProcessRunner(timeout: AppConstants.longCommandTimeout))
        let result = await Task.detached { () -> Result<LaunchResult, ClaudeLaunchError> in
            do throws(ClaudeLaunchError) {
                return .success(try await launcher.launch(pr: pr, purpose: purpose))
            } catch {
                return .failure(error)
            }
        }.value
        let error: ClaudeLaunchError
        switch result {
        case .success(let launched):
            await register(launched, pr: pr)
            return
        case .failure(let failure):
            error = failure
        }
        switch error {
        case .cloneNotFound(let repository):
            guard mayAskForClone else {
                claude.removeOverride(repository: repository)
                showAlert(ClaudeText.wrongClone(repository))
                return
            }
            guard rescanned else {
                await claude.rescan()
                await runLaunch(pr: pr, purpose: purpose, mayAskForClone: true, rescanned: true)
                return
            }
            NSApp.activate()
            guard let folder = FolderPicker.choose(
                prompt: ClaudeText.chooseClonePrompt, message: ClaudeText.cloneQuestion(repository))
            else { return }
            guard await CloneValidator.isClone(of: repository, directory: folder, runner: SystemProcessRunner()) else {
                showAlert(ClaudeText.wrongClone(repository))
                return
            }
            claude.setOverride(repository: repository, path: folder)
            await runLaunch(pr: pr, purpose: purpose, mayAskForClone: false, rescanned: true)
        case .worktree(let message):
            showAlert(ClaudeText.worktreePrefix + message)
        case .launchFailed(let message):
            showAlert(message)
        }
    }

    private func register(_ launched: LaunchResult, pr: PullRequest) async {
        let worktreesRoot = Self.expandedURL(claude.settings.worktreesRoot)
        guard let record = WorktreeRecord.registrable(
            pr: pr, directory: launched.directory, clone: launched.clone, worktreesRoot: worktreesRoot)
        else { return }
        await worktreeRegistry.add(record)
    }

    private func cleanUpWorktrees(snapshot: Snapshot) {
        let settings = claude.settings
        guard settings.removeWorktreeOnClose, !cleaningWorktrees, let client = githubClient else { return }
        cleaningWorktrees = true
        let registry = worktreeRegistry
        let worktreesRoot = Self.expandedURL(settings.worktreesRoot)
        Task.detached { [weak self] in
            let manager = WorktreeManager(
                runner: SystemProcessRunner(timeout: AppConstants.longCommandTimeout), worktreesRoot: worktreesRoot)
            let candidates = WorktreeCleanup.stale(records: await registry.records(), snapshot: snapshot)
            var present: [WorktreeRecord] = []
            for record in candidates {
                if FileManager.default.fileExists(atPath: record.path) {
                    present.append(record)
                } else {
                    await registry.remove(path: record.path)
                }
            }
            if !present.isEmpty, let states = try? await client.pullRequestStates(ids: present.map(\.pullRequestID)) {
                for record in WorktreeCleanup.confirmedClosed(candidates: present, states: states) {
                    let removed = await manager.removeIfClean(
                        path: URL(fileURLWithPath: record.path),
                        clone: URL(fileURLWithPath: record.clone),
                        number: record.number)
                    if removed { await registry.remove(path: record.path) }
                }
            }
            await self?.finishWorktreeCleanup()
        }
    }

    private func finishWorktreeCleanup() {
        cleaningWorktrees = false
    }

    private static func expandedURL(_ path: String) -> URL {
        URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }

    private func showAlert(_ message: String, title: String = ClaudeText.alertTitle) {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: ClaudeText.alertOK)
        alert.runModal()
    }
}
