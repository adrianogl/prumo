extension GitHubClient: AccountClient {
    public func rerunFailedJobs(pr: PullRequest) async throws(ProviderError) {
        guard let runID = pr.failedRunID else { throw .unexpectedResponse }
        try await rerunFailedJobs(repository: pr.repository, runID: runID)
    }

    public func cancelAndRerun(pr: PullRequest, runIDs: [Int]) async throws(ProviderError) {
        guard !runIDs.isEmpty else { throw .unexpectedResponse }
        try await cancelAndRerun(repository: pr.repository, runIDs: runIDs)
    }
}
