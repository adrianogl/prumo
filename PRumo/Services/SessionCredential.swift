import Synchronization
import PRumoKit

final class SessionCredential: Sendable {
    private let state: Mutex<(token: String, client: any AccountClient)>

    init(token: String, client: any AccountClient) {
        state = Mutex((token, client))
    }

    var token: String {
        state.withLock { $0.token }
    }

    var client: any AccountClient {
        state.withLock { $0.client }
    }

    func replace(token: String, client: any AccountClient) {
        state.withLock { $0 = (token, client) }
    }
}
