import Foundation

public enum ParallelRefresh {
    public typealias Session = (accountID: String, coordinator: RefreshCoordinator)

    public static func run(
        _ sessions: [Session], previous: [String: ConnectionState], options: TransitionOptions, now: Date,
        deadline: Duration = PollingConstants.accountDeadline
    ) async -> [AccountRefreshResult] {
        await withTaskGroup(of: (Int, AccountRefreshResult).self) { group in
            for (index, session) in sessions.enumerated() {
                let state = previous[session.accountID]
                group.addTask {
                    (index, await refresh(session, previous: state, options: options, now: now, deadline: deadline))
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
        _ session: Session, previous: ConnectionState?, options: TransitionOptions, now: Date, deadline: Duration
    ) async -> AccountRefreshResult {
        if let previous, !AccountSchedule.shouldRefresh(previous, now: now) {
            let snapshot = await session.coordinator.lastSnapshot()
            return AccountRefreshResult(accountID: session.accountID, snapshot: snapshot, events: [], state: previous)
        }
        return await withCheckedContinuation { continuation in
            let gate = FirstResultGate(continuation)
            let timer = Task {
                try? await Task.sleep(for: deadline)
                guard !Task.isCancelled else { return }
                let snapshot = await session.coordinator.lastSnapshot()
                gate.resume(AccountRefreshResult(
                    accountID: session.accountID, snapshot: snapshot, events: [],
                    state: .offline(lastSuccess: snapshot?.fetchedAt)
                ))
            }
            Task {
                let result = await session.coordinator.refresh(options: options)
                timer.cancel()
                gate.resume(AccountRefreshResult(
                    accountID: session.accountID, snapshot: result.snapshot, events: result.events, state: result.state
                ))
            }
        }
    }
}
