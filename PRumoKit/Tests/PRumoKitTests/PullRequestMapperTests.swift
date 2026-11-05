import Foundation
import Testing
@testable import PRumoKit

struct PullRequestMapperTests {
    private func snapshot() throws -> Snapshot {
        try PullRequestMapper.snapshot(mineJSON: fixture("search-mine"), reviewJSON: fixture("search-review"), now: .fixed)
    }

    @Test func mapsCIStatuses() throws {
        let s = try snapshot()
        #expect(s.mine.map(\.ci) == [.success(total: 12), .failure(failedChecks: ["unit-tests"], total: 12), .pending(done: 4, total: 9), .none])
    }

    @Test func detectsBotsAndConflict() throws {
        let s = try snapshot()
        #expect(s.mine[1].comments[0].authorIsBot)
        #expect(!s.mine[0].comments[0].authorIsBot)
        #expect(s.mine[3].mergeable == .conflicting)
        #expect(s.mine[2].isDraft)
        #expect(s.mine[3].reviews.map(\.state) == [.changesRequested])
        #expect(s.mine[0].reviews.map(\.state) == [.approved, .approved])
    }

    @Test func reviewRequestedAtComesFromViewerEvent() throws {
        let s = try snapshot()
        #expect(s.toReview[0].reviewRequestedAt == ISO8601DateFormatter().date(from: "2026-11-05T09:30:00Z"))
        #expect(s.toReview[1].reviewRequestedAt == nil)
        #expect(s.mine[0].reviewRequestedAt == nil)
    }

    @Test func viewerLoginIsRead() throws {
        let s = try snapshot()
        #expect(s.viewer == "adriano")
        #expect(s.fetchedAt == .fixed)
    }

    @Test func mapsBasicFields() throws {
        let pr = try snapshot().mine[0]
        #expect(pr.number == 101)
        #expect(pr.repository == "acme/api")
        #expect(pr.headSHA == "sha101")
        #expect(pr.commentCount == 1)
        #expect(pr.additions == 10 && pr.deletions == 2)
        #expect(pr.url == URL(string: "https://github.com/acme/api/pull/101"))
    }

    @Test func nullAuthorBecomesGhost() throws {
        #expect(try snapshot().toReview[1].author == "ghost")
    }

    @Test func ciIsTerminal() {
        #expect(!CIStatus.none.isTerminal)
        #expect(!CIStatus.pending(done: 1, total: 2).isTerminal)
        #expect(CIStatus.success(total: 2).isTerminal)
        #expect(CIStatus.failure(failedChecks: ["a"], total: 2).isTerminal)
    }
}
