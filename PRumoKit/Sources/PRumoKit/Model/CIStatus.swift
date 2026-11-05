public enum CIStatus: Sendable, Codable, Equatable {
    case none
    case pending(done: Int, total: Int)
    case success(total: Int)
    case failure(failedChecks: [String], total: Int)

    public var isTerminal: Bool {
        switch self {
        case .success, .failure: true
        case .none, .pending: false
        }
    }
}
