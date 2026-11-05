import Foundation

public actor RefreshCoordinator {
    public typealias Fetch = @Sendable () async throws(GitHubError) -> Snapshot

    private let fetch: Fetch
    private let accountID: String
    private let store: SnapshotStore
    private var lastKnown: Snapshot?
    private var pendingEvents: [NotificationEvent] = []
    private var tail: Task<RefreshResult, Never>?

    public init(accountID: String = "", fetch: @escaping Fetch, store: SnapshotStore) {
        self.accountID = accountID
        self.fetch = fetch
        self.store = store
    }

    public typealias RefreshResult = (snapshot: Snapshot?, events: [NotificationEvent], state: ConnectionState)

    public func refresh(options: TransitionOptions = .init()) async -> RefreshResult {
        let previous = tail
        let task = Task { () -> RefreshResult in
            _ = await previous?.value
            return await self.perform(options: options)
        }
        tail = task
        return await task.value
    }

    public func carryOver(_ events: [NotificationEvent]) {
        pendingEvents.append(contentsOf: events)
    }

    public func lastSnapshot() async -> Snapshot? {
        if let lastKnown { return lastKnown }
        return await store.load()
    }

    private func perform(options: TransitionOptions) async -> RefreshResult {
        let stored = await lastSnapshot()
        let carried = pendingEvents
        do {
            let fetched = try await fetch()
            let stamped = accountID.isEmpty ? fetched : fetched.stamped(accountID: accountID)
            let fresh = stamped.keepingKnownMergeable(from: stored)
            let events = TransitionEngine.events(from: stored, to: fresh, options: options)
            lastKnown = fresh
            try? await store.save(fresh)
            pendingEvents.removeAll()
            return (fresh, carried + events, .ok)
        } catch {
            return (stored, [], Self.state(for: error, stored: stored))
        }
    }

    private static func state(for error: GitHubError, stored: Snapshot?) -> ConnectionState {
        switch error {
        case .unauthorized: .unauthorized
        case .rateLimited(let resetAt): .rateLimited(resetAt: resetAt)
        case .network, .server, .graphQL: .offline(lastSuccess: stored?.fetchedAt)
        case .unexpectedResponse: .unexpectedResponse(lastSuccess: stored?.fetchedAt)
        }
    }
}
