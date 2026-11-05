import Foundation

public actor RefreshCoordinator {
    public typealias Fetch = @Sendable () async throws(GitHubError) -> Snapshot

    private let fetch: Fetch
    private let store: SnapshotStore

    public init(fetch: @escaping Fetch, store: SnapshotStore) {
        self.fetch = fetch
        self.store = store
    }

    public func refresh() async -> (snapshot: Snapshot?, events: [NotificationEvent], state: ConnectionState) {
        let stored = await store.load()
        do {
            let fresh = try await fetch()
            let events = TransitionEngine.events(from: stored, to: fresh)
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
        }
    }
}
