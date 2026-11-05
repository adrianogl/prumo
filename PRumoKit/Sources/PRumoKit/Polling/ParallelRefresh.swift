import Foundation

public enum ParallelRefresh {
    public typealias Session = (accountID: String, coordinator: RefreshCoordinator)

    public static func run(
        _ sessions: [Session], previous: [String: ConnectionState], options: TransitionOptions, now: Date
    ) async -> [AccountRefreshResult] {
        await withTaskGroup(of: (Int, AccountRefreshResult).self) { group in
            for (index, session) in sessions.enumerated() {
                let state = previous[session.accountID]
                group.addTask {
                    (index, await refresh(session, previous: state, options: options, now: now))
                }
            }
            var results = [AccountRefreshResult?](repeating: nil, count: sessions.count)
            for await (index, result) in group {
                results[index] = result
            }
            return results.compactMap { $0 }
        }
    }

    private static func refresh(
        _ session: Session, previous: ConnectionState?, options: TransitionOptions, now: Date
    ) async -> AccountRefreshResult {
        if let previous, !AccountSchedule.shouldRefresh(previous, now: now) {
            let snapshot = await session.coordinator.lastSnapshot()
            return AccountRefreshResult(accountID: session.accountID, snapshot: snapshot, events: [], state: previous)
        }
        let result = await session.coordinator.refresh(options: options)
        return AccountRefreshResult(
            accountID: session.accountID, snapshot: result.snapshot, events: result.events, state: result.state
        )
    }
}
