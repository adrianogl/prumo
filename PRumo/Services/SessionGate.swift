import Synchronization
import PRumoKit

final class SessionGate: Sendable {
    private let stopped = Mutex(false)

    var isStopped: Bool {
        stopped.withLock { $0 }
    }

    func stop() {
        stopped.withLock { $0 = true }
    }

    func check() throws(GitHubError) {
        if isStopped { throw .network }
    }
}
