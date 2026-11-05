extension GitHubClient: AccountClient {
    public func rerunFailedJobs(pr: PullRequest) async throws(ProviderError) {
        guard let runID = pr.failedRunID else { throw .unexpectedResponse }
        try await rerunFailedJobs(repository: pr.repository, runID: runID)
    }
}
