public protocol AccountClient: Sendable {
    func fetchSnapshot() async throws(GitHubError) -> Snapshot
    func pullRequestStates(ids: [String]) async throws(GitHubError) -> [String: PRState]
    func rerunFailedJobs(pr: PullRequest) async throws(GitHubError)
}
