import Foundation
import Testing
@testable import PRumoKit

struct SidebarCountsTests {
    @Test func countsByRepositoryMostFirstThenByName() {
        let prs = [
            PullRequest.fixture(id: "1", repository: "acme/web"),
            PullRequest.fixture(id: "2", repository: "acme/loja"),
            PullRequest.fixture(id: "3", repository: "acme/loja"),
            PullRequest.fixture(id: "4", repository: "acme/api"),
        ]
        let counts = SidebarCounts.repositories(prs)
        #expect(counts.map(\.key) == ["acme/loja", "acme/api", "acme/web"])
        #expect(counts.map(\.count) == [2, 1, 1])
    }

    @Test func emptyListHasNoRepositories() {
        #expect(SidebarCounts.repositories([]).isEmpty)
    }
}

struct TabSourceTests {
    @Test func mergeTabOnlyHasReadyPullRequests() {
        let ready = PullRequest.fixture(id: "ready", ci: .success(total: 1), mergeReady: true)
        let notReady = PullRequest.fixture(id: "wip", ci: .pending(done: 0, total: 1))
        let draft = PullRequest.fixture(id: "draft", isDraft: true, ci: .success(total: 1), mergeReady: true)
        let snapshot = Snapshot.fixture(mine: [ready, notReady, draft])
        let settings = OrganizationSettings()
        #expect(TabSource.pullRequests(snapshot, tab: .mine, settings: settings).map(\.id) == ["ready", "wip", "draft"])
        #expect(TabSource.pullRequests(snapshot, tab: .merge, settings: settings).map(\.id) == ["ready"])
    }
}
