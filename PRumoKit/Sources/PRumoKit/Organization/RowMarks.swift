public struct RowMarks: Codable, Equatable, Sendable {
    public var pinned: Set<String>
    public var muted: [String: MutedPullRequest]

    public init(pinned: Set<String> = [], muted: [String: MutedPullRequest] = [:]) {
        self.pinned = pinned
        self.muted = muted
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pinned = c.decodeLossy(Set<String>.self, forKey: .pinned, default: [])
        muted = c.decodeLossyDictionary(MutedPullRequest.self, forKey: .muted)
    }

    public func isPinned(_ id: String) -> Bool { pinned.contains(id) }

    public func isMuted(_ id: String) -> Bool { muted[id] != nil }

    public func pruned(states: [String: PRState]) -> RowMarks {
        func isFinished(_ id: String) -> Bool {
            states[id] == .closed || states[id] == .merged
        }
        return RowMarks(
            pinned: pinned.filter { !isFinished($0) },
            muted: muted.filter { !isFinished($0.key) }
        )
    }
}
