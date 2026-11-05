actor GitLabCapabilityCache {
    private(set) var current: GitLabCapabilities

    init(_ initial: GitLabCapabilities = GitLabCapabilities(hasReviewState: true, hasDetailedMergeStatus: true)) {
        current = initial
    }

    func update(_ capabilities: GitLabCapabilities) {
        current = capabilities
    }
}
