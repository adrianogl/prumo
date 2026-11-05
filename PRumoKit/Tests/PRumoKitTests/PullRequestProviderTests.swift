import Foundation
import Testing
@testable import PRumoKit

@Suite struct PullRequestProviderTests {
    private let gitlabURL = URL(string: "https://gitlab.empresa.com/vendas/api/-/merge_requests/341")!

    @Test func providerOwnsItsPullRequestIDs() {
        let gitlab = GitLabID.make(host: "gitlab.local:8443", projectID: 7, iid: 341)
        let github = "PR_kwDOAbc123"
        #expect(ProviderKind.gitlab.owns(pullRequestID: gitlab))
        #expect(!ProviderKind.gitlab.owns(pullRequestID: github))
        #expect(ProviderKind.github.owns(pullRequestID: github))
        #expect(!ProviderKind.github.owns(pullRequestID: gitlab))
    }

    @Test func providerDefaultsToGitHubInOldJSON() throws {
        let data = try JSONEncoder().encode(PullRequest.fixture())
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        object.removeValue(forKey: "provider")
        object.removeValue(forKey: "mergeReady")
        object.removeValue(forKey: "failedJobID")
        let old = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(PullRequest.self, from: old)
        #expect(decoded.provider == .github)
        #expect(decoded.mergeReady == nil)
        #expect(decoded.failedJobID == nil)
    }

    @Test func gitlabFieldsRoundTrip() throws {
        let pr = PullRequest.fixture(provider: .gitlab, mergeReady: true, failedJobID: 9)
        let decoded = try JSONDecoder().decode(PullRequest.self, from: JSONEncoder().encode(pr))
        #expect(decoded == pr)
    }

    @Test func mergedProviderDefaultsToGitHubInOldJSON() throws {
        let json = #"{"id":"M","number":1,"title":"t","url":"https://github.com/a/b/pull/1","repository":"a/b","mergedAt":800000000}"#
        let merged = try JSONDecoder().decode(MergedPullRequest.self, from: Data(json.utf8))
        #expect(merged.provider == .github)
    }

    @Test func referenceUsesBangForGitLab() {
        #expect(PullRequest.fixture(number: 341, provider: .gitlab).reference == "!341")
        #expect(PullRequest.fixture(number: 812).reference == "#812")
    }

    @Test func repositoryKeyForGitLabIncludesHost() {
        let pr = PullRequest.fixture(url: gitlabURL, repository: "vendas/api", provider: .gitlab)
        #expect(pr.repositoryKey == "gitlab.empresa.com/vendas/api")
        #expect(PullRequest.fixture(repository: "acme/loja").repositoryKey == "acme/loja")
    }

    @Test func checksURLPerProvider() {
        #expect(PullRequest.fixture().checksURL.absoluteString == "https://github.com/acme/loja/pull/812/checks")
        #expect(PullRequest.fixture(url: gitlabURL, provider: .gitlab).checksURL.absoluteString == gitlabURL.absoluteString + "/pipelines")
    }

    @Test func mergedReferenceAndRepositoryKey() {
        let merged = MergedPullRequest(
            id: "M", number: 341, title: "t", url: gitlabURL, repository: "vendas/api", mergedAt: .fixed, provider: .gitlab
        )
        #expect(merged.reference == "!341")
        #expect(merged.repositoryKey == "gitlab.empresa.com/vendas/api")
    }
}
