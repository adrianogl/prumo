import Testing
@testable import PRumoKit

@Suite struct GitLabIDTests {
    @Test func gitLabIDRoundTrip() {
        let id = GitLabID.make(host: "GitLab.Empresa.com", projectID: 77, iid: 341)
        #expect(id == "gitlab:gitlab.empresa.com:77:341")
        let parsed = GitLabID.parse(id)
        #expect(parsed?.host == "gitlab.empresa.com")
        #expect(parsed?.projectID == 77)
        #expect(parsed?.iid == 341)
    }

    @Test func gitLabIDDiffersBetweenHosts() {
        #expect(GitLabID.make(host: "gitlab.com", projectID: 1, iid: 2) != GitLabID.make(host: "gitlab.empresa.com", projectID: 1, iid: 2))
    }

    @Test func parseRejectsMalformedIDs() {
        #expect(GitLabID.parse("PR_812") == nil)
        #expect(GitLabID.parse("gitlab:host:1") == nil)
        #expect(GitLabID.parse("gitlab:host:x:2") == nil)
    }
}
