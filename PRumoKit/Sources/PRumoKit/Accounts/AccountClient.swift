public protocol AccountClient: Sendable {
    func fetchSnapshot() async throws(ProviderError) -> Snapshot
    func pullRequestStates(ids: [String]) async throws(ProviderError) -> [String: PRState]
    func rerunFailedJobs(pr: PullRequest) async throws(ProviderError)
    func cancelAndRerun(pr: PullRequest) async throws(ProviderError)
}
