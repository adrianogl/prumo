import Foundation

public actor RefreshCoordinator {
    public typealias Fetch = @Sendable () async throws(GitHubError) -> Snapshot

    private let fetch: Fetch
    private let store: SnapshotStore
    private var lastKnown: Snapshot?
    private var tail: Task<RefreshResult, Never>?

    public init(fetch: @escaping Fetch, store: SnapshotStore) {
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

    private func perform(options: TransitionOptions) async -> RefreshResult {
        let stored: Snapshot?
        if let lastKnown {
            stored = lastKnown
        } else {
            stored = await store.load()
        }
        do {
            let fresh = try await fetch().keepingKnownMergeable(from: stored)
            let events = TransitionEngine.events(from: stored, to: fresh, options: options)
            lastKnown = fresh
            try? await store.save(fresh)
            return (fresh, events, .ok)
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
