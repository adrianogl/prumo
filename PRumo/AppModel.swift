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
    let accounts: AccountsStore
    let claude: ClaudeSettingsStore
    let integrations: IntegrationSettingsStore
    let organization: OrganizationStore
    let preferences: NotificationPreferencesStore
    private(set) var launching: Set<String> = []
    private(set) var rerunning: Set<String> = []
    private(set) var hotKey: HotKeyCombo
    private(set) var hotKeyRegistered = true

    private var sessions: [String: AccountSession] = [:]

    @ObservationIgnored private let notifications: NotificationService
    @ObservationIgnored private let tokenStore: @Sendable (String) -> TokenStore
    @ObservationIgnored private let tokenResolver: AccountTokenResolver
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let worktreeRegistry: WorktreeRegistry
    @ObservationIgnored private let reminderStore: ReminderStore
    @ObservationIgnored private let widgetPublisher: WidgetPublisher?
    @ObservationIgnored private var cleaningWorktrees = false
    @ObservationIgnored private var pruningMarks = false
    @ObservationIgnored private var lastMarksPrune = Date.distantPast
    @ObservationIgnored private var lastSnapshots: [String: Snapshot] = [:]
    @ObservationIgnored private var activityBaselines: [String: Snapshot] = [:]
    @ObservationIgnored private var reminders: ReminderState?
    @ObservationIgnored private var pollingTask: Task<Void, Never>?
    @ObservationIgnored private var sleepTask: Task<Void, Never>?
    @ObservationIgnored private var startupTask: Task<Void, Never>?
    @ObservationIgnored private let globalHotKey = GlobalHotKey { _ = StatusItemToggle.toggle() }

    init(
        notifications: NotificationService,
        tokenStore: @escaping @Sendable (String) -> TokenStore = {
            KeychainTokenStore(account: AccountStorage.keychainAccount(for: $0))
        },
        defaults: UserDefaults = .standard,
        accounts: AccountsStore? = nil,
        claude: ClaudeSettingsStore? = nil,
        integrations: IntegrationSettingsStore? = nil,
        organization: OrganizationStore? = nil,
        preferences: NotificationPreferencesStore? = nil,
        worktreeRegistry: WorktreeRegistry = WorktreeRegistry(fileURL: WorktreeRegistry.defaultURL()),
        reminderStore: ReminderStore = ReminderStore(fileURL: ReminderStore.defaultURL()),
        widgetPublisher: WidgetPublisher? = WidgetPublisher.makeDefault()
    ) {
        self.widgetPublisher = widgetPublisher
        self.worktreeRegistry = worktreeRegistry
        self.reminderStore = reminderStore
        self.notifications = notifications
        self.tokenStore = tokenStore
        tokenResolver = AccountTokenResolver(tokenStore: tokenStore, gh: .system())
        self.defaults = defaults
        self.accounts = accounts ?? AccountsStore(defaults: defaults)
        self.claude = claude ?? ClaudeSettingsStore(defaults: defaults)
        self.integrations = integrations ?? IntegrationSettingsStore(defaults: defaults)
        self.organization = organization ?? OrganizationStore(defaults: defaults)
        self.preferences = preferences ?? NotificationPreferencesStore(defaults: defaults)
        hotKey = defaults.data(forKey: AppConstants.hotKeyKey)
            .flatMap { try? JSONDecoder().decode(HotKeyCombo.self, from: $0) }
            .flatMap { $0.isValid ? $0 : nil } ?? .standard
        notifications.onFixWithClaude = { [weak self] id, url in
            guard let self, let pr = self.snapshot?.mine.first(where: { $0.id == id }) else {
                NSWorkspace.shared.open(url)
                return
            }
            self.launchClaude(pr: pr, purpose: .fixCI)
        }
        notifications.onMute = { [weak self] id in
            guard let self,
                  let pr = ((self.snapshot?.mine ?? []) + (self.snapshot?.toReview ?? [])).first(where: { $0.id == id }),
                  !self.organization.settings.marks.isMuted(id)
            else { return }
            self.organization.toggleMute(pr, now: .now)
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

    var login: String? {
        accounts.list.accounts.first?.login
    }

    var origin: TokenOrigin? {
        accounts.list.accounts.first?.origin
    }

    func session(for pr: PullRequest) -> AccountSession? {
        sessions[pr.accountID]
    }

    func accountLabel(for pr: PullRequest) -> AccountLabel? {
        AccountLabel.forRow(accountID: pr.accountID, accounts: accounts.list.accounts)
    }

    func start() {
        Task { await claude.rescan() }
        startupTask?.cancel()
        startupTask = Task {
            var known: [String: String] = [:]
            if !accounts.hasStoredList, let migrated = await migrateLegacyAccount() {
                known[migrated.account.id] = migrated.token
            }
            guard !Task.isCancelled else { return }
            let list = accounts.list.accounts
            guard let first = list.first else {
                needsOnboarding = true
                return
            }
            let tokens = await resolveTokens(list, known: known)
            guard !Task.isCancelled else { return }
            if list.count == 1, tokens[first.id] == nil {
                accounts.statuses[first.id] = AccountStatus(state: .unauthorized)
                needsOnboarding = true
                return
            }
            needsOnboarding = false
            defaults.set(true, forKey: AppConstants.onboardingDoneKey)
            let notifications = notifications
            Task.detached { _ = await notifications.requestAuthorization() }
            await begin(tokens: tokens)
        }
    }

    private func migrateLegacyAccount() async -> (account: Account, token: String)? {
        let onboarded = defaults.bool(forKey: AppConstants.onboardingDoneKey)
        let storedOrigin = defaults.string(forKey: AppConstants.tokenOriginKey).flatMap(TokenOrigin.init(rawValue:))
        let resolver = TokenResolver(
            store: tokenStore(AccountMigration.legacyAccountID), gh: GhCLITokenSource(runner: SystemProcessRunner()))
        var resolved = await resolver.resolve()
        if resolved == nil, onboarded, storedOrigin == .ghCLI {
            for _ in 0..<AppConstants.ghTokenRetryAttempts {
                try? await Task.sleep(for: AppConstants.ghTokenRetryDelay)
                guard !Task.isCancelled else { return nil }
                resolved = await resolver.resolve()
                if resolved != nil { break }
            }
        }
        guard !Task.isCancelled, let resolved else { return nil }
        let legacy = LegacyAccountState(
            login: await legacyLogin(token: resolved.token),
            origin: resolved.origin,
            onboardingDone: onboarded || resolved.origin == .pasted)
        guard !Task.isCancelled, let account = AccountMigration.account(from: legacy, existing: nil) else { return nil }
        accounts.list = AccountList(accounts: [account])
        accounts.save()
        let migrated = AccountMigration.reminders(await reminderStore.load(), migrated: account)
        reminders = migrated
        try? await reminderStore.save(migrated)
        return (account, resolved.token)
    }

    private func legacyLogin(token: String) async -> String? {
        if let stored = defaults.string(forKey: AppConstants.accountLoginKey), !stored.isEmpty { return stored }
        let url = AccountStorage.snapshotURL(for: AccountMigration.legacyAccountID)
        if let viewer = await SnapshotStore(fileURL: url).load()?.viewer, !viewer.isEmpty { return viewer }
        let client = GitHubClient(token: token)
        let fetched = await Task.detached { () -> String? in
            do throws(GitHubError) {
                return try await client.viewerLogin()
            } catch {
                return nil
            }
        }.value
        guard let fetched, !fetched.isEmpty else { return nil }
        return fetched
    }

    private func resolveTokens(_ list: [Account], known: [String: String]) async -> [String: String] {
        let resolver = tokenResolver
        return await withTaskGroup(of: (String, String?).self) { group in
            for account in list {
                let token = known[account.id]
                group.addTask {
                    if let token { return (account.id, token) }
                    return (account.id, await Self.resolveToken(account, resolver: resolver))
                }
            }
            var tokens: [String: String] = [:]
            for await (id, token) in group {
                if let token { tokens[id] = token }
            }
            return tokens
        }
    }

    nonisolated private static func resolveToken(_ account: Account, resolver: AccountTokenResolver) async -> String? {
        if let token = await resolver.token(for: account) { return token }
        guard account.origin == .ghCLI else { return nil }
        for _ in 0..<AppConstants.ghTokenRetryAttempts {
            try? await Task.sleep(for: AppConstants.ghTokenRetryDelay)
            guard !Task.isCancelled else { return nil }
            if let token = await resolver.token(for: account) { return token }
        }
        return nil
    }

    func registerHotKey() {
        hotKeyRegistered = globalHotKey.register(hotKey)
    }

    func suspendHotKey() {
        globalHotKey.unregister()
    }

    func resumeHotKey() {
        registerHotKey()
    }

    func setHotKey(_ combo: HotKeyCombo) -> Bool {
        guard combo.isValid else { return false }
        guard globalHotKey.register(combo) else {
            hotKeyRegistered = globalHotKey.register(hotKey)
            return false
        }
        hotKey = combo
        hotKeyRegistered = true
        if let data = try? JSONEncoder().encode(combo) {
            defaults.set(data, forKey: AppConstants.hotKeyKey)
        }
        return true
    }

    func connect(token: String, origin: TokenOrigin, login: String) throws {
        let candidate = Account(id: UUID().uuidString.lowercased(), login: login, origin: origin)
        var account = accounts.list.accounts.first { $0.isSameIdentity(as: candidate) } ?? candidate
        account.origin = origin
        let store = tokenStore(account.id)
        if origin == .pasted {
            try store.write(token)
        } else {
            try store.delete()
        }
        startupTask?.cancel()
        for other in accounts.list.accounts where other.id != account.id {
            discard(other.id)
        }
        accounts.list = AccountList(accounts: [account])
        accounts.statuses = [account.id: AccountStatus()]
        accounts.save()
        defaults.set(true, forKey: AppConstants.onboardingDoneKey)
        needsOnboarding = false
        connection = .ok
        startupTask = Task { await begin(tokens: [account.id: token]) }
    }

    func addAccount(_ account: Account, token: String) throws {
        guard !accounts.list.accounts.contains(where: { $0.isSameIdentity(as: account) }) else {
            throw DuplicateAccountError()
        }
        if account.origin == .pasted {
            try tokenStore(account.id).write(token)
        }
        accounts.list.add(account)
        accounts.statuses[account.id] = AccountStatus()
        accounts.save()
        sessions[account.id] = makeSession(account, token: token)
        defaults.set(true, forKey: AppConstants.onboardingDoneKey)
        needsOnboarding = false
        updateConnection()
        resumePolling()
    }

    func removeAccount(id: String) {
        guard accounts.list.account(id: id) != nil else { return }
        guard accounts.list.accounts.count > 1 else {
            signOut()
            return
        }
        discard(id)
        accounts.save()
        recombine()
        updateConnection()
        if let snapshot { publishWidget(fresh: snapshot) }
    }

    func reconnect(id: String) {
        guard let account = accounts.list.account(id: id) else { return }
        sessions.removeValue(forKey: id)?.gate.stop()
        accounts.statuses[id] = AccountStatus(lastSuccess: accounts.statuses[id]?.lastSuccess)
        updateConnection()
        let resolver = tokenResolver
        Task {
            let token = await Self.resolveToken(account, resolver: resolver)
            guard let current = accounts.list.account(id: id), sessions[id] == nil else { return }
            guard let token else {
                accounts.statuses[id]?.state = .unauthorized
                updateConnection()
                return
            }
            sessions[id] = makeSession(current, token: token)
            resumePolling()
        }
    }

    func renameAccount(id: String, nickname: String) {
        accounts.list.rename(id: id, nickname: nickname)
        accounts.save()
        refreshSessionAccount(id: id)
    }

    func requestNotificationPermission() async -> Bool {
        await notifications.requestAuthorization()
    }

    private func begin(tokens: [String: String]) async {
        stopSessions()
        let list = accounts.list.accounts
        for account in list {
            let lastSuccess = accounts.statuses[account.id]?.lastSuccess
            if let token = tokens[account.id] {
                sessions[account.id] = makeSession(account, token: token)
                accounts.statuses[account.id] = AccountStatus(lastSuccess: lastSuccess)
            } else {
                accounts.statuses[account.id] = AccountStatus(state: .unauthorized, lastSuccess: lastSuccess)
            }
        }
        var stored: [String: Snapshot] = [:]
        for account in list {
            let url = AccountStorage.snapshotURL(for: account.id)
            stored[account.id] = await SnapshotStore(fileURL: url).load()?.stamped(accountID: account.id)
        }
        guard !Task.isCancelled else { return }
        lastSnapshots = stored
        activityBaselines = stored
        recombine()
        updateConnection()
        startPolling()
    }

    private func makeSession(_ account: Account, token: String) -> AccountSession {
        let client = GitHubClient(token: token)
        let gate = SessionGate()
        let coordinator = RefreshCoordinator(
            accountID: account.id,
            fetch: { () async throws(GitHubError) -> Snapshot in
                try gate.check()
                let fetched = try await client.fetchSnapshot()
                try gate.check()
                return fetched
            },
            store: SnapshotStore(fileURL: AccountStorage.snapshotURL(for: account.id)))
        return AccountSession(account: account, token: token, client: client, coordinator: coordinator, gate: gate)
    }

    private func stopSessions() {
        for session in sessions.values {
            session.gate.stop()
        }
        sessions = [:]
    }

    private func discard(_ id: String) {
        let session = sessions.removeValue(forKey: id)
        session?.gate.stop()
        try? tokenStore(id).delete()
        accounts.list.remove(id: id)
        accounts.statuses.removeValue(forKey: id)
        lastSnapshots.removeValue(forKey: id)
        activityBaselines.removeValue(forKey: id)
        let url = AccountStorage.snapshotURL(for: id)
        Task { await Self.purge(session, snapshotURL: url) }
    }

    nonisolated private static func purge(_ session: AccountSession?, snapshotURL: URL) async {
        if let session { _ = await session.coordinator.refresh() }
        await SnapshotStore(fileURL: snapshotURL).delete()
    }

    private func refreshSessionAccount(id: String) {
        guard let account = accounts.list.account(id: id), let session = sessions[id] else { return }
        sessions[id] = session.with(account: account)
    }

    private func recombine() {
        let parts = accounts.list.accounts.compactMap { account in
            lastSnapshots[account.id].map { AccountPart(accountID: account.id, snapshot: $0) }
        }
        snapshot = AccountMerge.combine(parts)
    }

    private func updateConnection() {
        let list = accounts.list.accounts
        guard list.count == 1, let only = list.first else {
            connection = .ok
            return
        }
        connection = accounts.statuses[only.id]?.state ?? .ok
    }

    private func resumePolling() {
        if pollingTask == nil {
            startPolling()
        } else {
            sleepTask?.cancel()
        }
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
        stopPolling()
        let stopped = Array(sessions.values)
        stopSessions()
        let ids = Set(accounts.list.accounts.map(\.id) + [AccountMigration.legacyAccountID])
        for id in ids {
            try? tokenStore(id).delete()
        }
        Task {
            for session in stopped {
                _ = await session.coordinator.refresh()
            }
            for id in ids {
                await SnapshotStore(fileURL: AccountStorage.snapshotURL(for: id)).delete()
            }
        }
        accounts.clear()
        lastSnapshots = [:]
        activityBaselines = [:]
        reminders = ReminderState()
        let reminderStore = reminderStore
        Task { try? await reminderStore.save(ReminderState()) }
        snapshot = nil
        widgetPublisher?.publish(.disconnected)
        lastRefresh = nil
        connection = .ok
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
        let active = accounts.list.accounts.compactMap { sessions[$0.id] }
        guard !active.isEmpty else { return false }
        let options = TransitionOptions(
            ignoreDraftReviews: organization.settings.ignoreDraftsInReview,
            includeTeamRequests: organization.settings.includeTeamRequests,
            ignoredCommentAuthors: organization.settings.commentAuthorFilter.ignoredAuthors
        )
        let results = await ParallelRefresh.run(
            active.map { (accountID: $0.account.id, coordinator: $0.coordinator) },
            previous: accounts.statuses.compactMapValues(\.state),
            options: options,
            now: .now)
        guard !Task.isCancelled else { return false }
        let now = Date.now
        let gates = Dictionary(active.map { ($0.account.id, $0.gate) }, uniquingKeysWith: { first, _ in first })
        var perAccount: [(accountID: String, events: [NotificationEvent])] = []
        var refreshed = false
        for result in results {
            let id = result.accountID
            guard let gate = gates[id], !gate.isStopped, accounts.list.account(id: id) != nil else { continue }
            var status = accounts.statuses[id] ?? AccountStatus()
            status.state = result.state
            if result.state == .ok { status.lastSuccess = now }
            accounts.statuses[id] = status
            if let part = result.snapshot { lastSnapshots[id] = part.stamped(accountID: id) }
            perAccount.append((accountID: id, events: result.events))
            guard result.state == .ok, let fresh = result.snapshot else { continue }
            refreshed = true
            updateLogin(accountID: id, viewer: fresh.viewer)
            trackActivity(accountID: id, fresh: fresh, events: result.events)
        }
        recombine()
        updateConnection()
        if refreshed, let combined = snapshot {
            lastRefresh = now
            organization.pruneActivity(snapshot: combined)
            organization.learnRepositories(from: combined)
            cleanUpWorktrees(snapshot: combined)
            pruneMarks(snapshot: combined)
            publishWidget(fresh: combined)
            await deliverNotifications(fresh: combined, events: AccountMerge.events(perAccount, combined: combined))
        }
        return accounts.list.accounts.contains { accounts.statuses[$0.id]?.state != .unauthorized }
    }

    private func updateLogin(accountID: String, viewer: String) {
        guard !viewer.isEmpty, let account = accounts.list.account(id: accountID), account.login != viewer else { return }
        accounts.list.updateLogin(id: accountID, login: viewer)
        accounts.save()
        refreshSessionAccount(id: accountID)
    }

    private func publishWidget(fresh: Snapshot) {
        widgetPublisher?.publish(WidgetSummary.make(
            snapshot: fresh,
            ignoreDrafts: organization.settings.ignoreDraftsInReview,
            includeTeam: organization.settings.includeTeamRequests,
            muted: Set(organization.settings.marks.muted.keys),
            staleLimit: TimeInterval(preferences.preferences.staleReviewHours) * AppConstants.secondsPerHour,
            now: .now))
    }

    private func deliverNotifications(fresh: Snapshot, events: [NotificationEvent]) async {
        let now = Date.now
        preferences.refreshQuiet(now: now)
        let current: ReminderState
        if let reminders {
            current = reminders
        } else {
            current = await reminderStore.load()
        }
        let outcome = NotificationPipeline.run(
            events: events, snapshot: fresh, preferences: preferences.preferences,
            muted: Set(organization.settings.marks.muted.keys),
            ignoreDrafts: organization.settings.ignoreDraftsInReview,
            includeTeam: organization.settings.includeTeamRequests,
            reminders: current, now: now, calendar: .current)
        reminders = outcome.reminders
        try? await reminderStore.save(outcome.reminders)
        notifications.post(outcome.deliver, grouped: preferences.preferences.groupByPullRequest)
    }

    private func trackActivity(accountID: String, fresh: Snapshot, events: [NotificationEvent]) {
        let baseline = activityBaselines[accountID].flatMap { $0.viewer == fresh.viewer ? $0 : nil }
        let marks = organization.settings.marks
        let touched = ActivityTracker.touched(old: baseline, new: fresh, events: events)
        organization.recordActivity(touched.filter { !marks.isMuted($0) })
        activityBaselines[accountID] = fresh
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
        case .pin:
            organization.togglePin(pr)
        case .mute:
            organization.toggleMute(pr, now: .now)
        case .separator:
            break
        }
    }

    func isRerunning(_ pr: PullRequest) -> Bool {
        rerunning.contains(pr.id)
    }

    func rerunFailedJobs(pr: PullRequest, runID: Int) {
        guard !rerunning.contains(pr.id), let client = session(for: pr)?.client else { return }
        rerunning.insert(pr.id)
        let repository = pr.repository
        Task {
            let failure = await Task.detached { () -> GitHubError? in
                do throws(GitHubError) {
                    try await client.rerunFailedJobs(pr: pr)
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
        guard settings.removeWorktreeOnClose, !cleaningWorktrees, !sessions.isEmpty else { return }
        cleaningWorktrees = true
        let clients = sessions.mapValues(\.client)
        let fallback = accounts.list.accounts.first { $0.provider == .github }?.id ?? ""
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
            let owners = Dictionary(grouping: present) { $0.accountID ?? fallback }
            for (accountID, records) in owners {
                guard let client = clients[accountID],
                      let states = try? await client.pullRequestStates(ids: records.map(\.pullRequestID))
                else { continue }
                for record in WorktreeCleanup.confirmedClosed(candidates: records, states: states) {
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

    private func pruneMarks(snapshot: Snapshot) {
        let marks = organization.settings.marks
        let marked = marks.pinned.union(marks.muted.keys)
        let present = Set((snapshot.mine + snapshot.toReview).map(\.id))
        let absent = marked.subtracting(present)
        let clients = accounts.list.accounts.compactMap { sessions[$0.id]?.client }
        guard !absent.isEmpty, !pruningMarks, !clients.isEmpty,
              Date.now.timeIntervalSince(lastMarksPrune) >= AppConstants.marksPruneInterval
        else { return }
        pruningMarks = true
        lastMarksPrune = .now
        let ids = absent.sorted()
        Task.detached { [weak self] in
            var states: [String: PRState]?
            for client in clients {
                guard let found = try? await client.pullRequestStates(ids: ids) else { continue }
                states = (states ?? [:]).merging(found) { current, _ in current }
            }
            await self?.finishMarksPrune(states: states)
        }
    }

    private func finishMarksPrune(states: [String: PRState]?) {
        pruningMarks = false
        guard let states else { return }
        let marks = organization.settings.marks
        let pruned = marks.pruned(states: states)
        guard pruned != marks else { return }
        organization.settings.marks = pruned
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
