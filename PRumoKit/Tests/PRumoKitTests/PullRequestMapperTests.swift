import Foundation
import Testing
@testable import PRumoKit

struct PullRequestMapperTests {
    private func snapshot() throws -> Snapshot {
        try PullRequestMapper.snapshot(mineJSON: fixture("search-mine"), reviewJSON: fixture("search-review"), mergedJSON: nil, now: .fixed)
    }

    private func reviewJSON(replacingRequests requests: [[String: Any]], at index: Int, authorLogin: String? = nil) throws -> Data {
        var object = try JSONSerialization.jsonObject(with: fixture("search-review")) as! [String: Any]
        var data = object["data"] as! [String: Any]
        var search = data["search"] as! [String: Any]
        var nodes = search["nodes"] as! [[String: Any]]
        nodes[index]["reviewRequests"] = ["nodes": requests]
        if let authorLogin {
            nodes[index]["author"] = ["__typename": "User", "login": authorLogin]
        }
        search["nodes"] = nodes
        data["search"] = search
        object["data"] = data
        return try JSONSerialization.data(withJSONObject: object)
    }

    @Test func mapsCIStatuses() throws {
        let s = try snapshot()
        #expect(s.mine.map(\.ci) == [.success(total: 12), .failure(failedChecks: ["unit-tests"], total: 12), .pending(done: 4, total: 9), .none])
    }

    @Test func mapsPendingSinceAndRunsFromPendingChecks() throws {
        let pr = try snapshot().mine[2]
        #expect(pr.ciPendingSince == ISO8601DateFormatter().date(from: "2026-11-05T10:52:00Z"))
        #expect(pr.pendingRunIDs == [103005, 103006])
    }

    @Test func noPendingDataWhenCIFinished() throws {
        let s = try snapshot()
        for pr in [s.mine[0], s.mine[1], s.mine[3]] {
            #expect(pr.ciPendingSince == nil)
            #expect(pr.pendingRunIDs == [])
        }
    }

    @Test func detectsBotsAndConflict() throws {
        let s = try snapshot()
        #expect(s.mine[1].comments[0].authorIsBot)
        #expect(!s.mine[0].comments[0].authorIsBot)
        #expect(s.mine[3].mergeable == .conflicting)
        #expect(s.mine[2].isDraft)
        #expect(s.mine[3].reviews.map(\.state) == [.changesRequested, .commented])
        #expect(s.mine[0].reviews.map(\.state) == [.approved, .approved])
    }

    @Test func mapsReviewBodyAndURL() throws {
        let review = try snapshot().mine[3].reviews[1]
        #expect(review.id == "R4")
        #expect(review.author == "carla")
        #expect(!review.authorIsBot)
        #expect(review.body == "Dá para extrair essa função?")
        #expect(review.url == URL(string: "https://github.com/acme/web/pull/104#pullrequestreview-R4"))
    }

    @Test func reviewRequestedAtComesFromViewerEvent() throws {
        let s = try snapshot()
        #expect(s.toReview[0].reviewRequestedAt == ISO8601DateFormatter().date(from: "2026-11-05T09:30:00Z"))
        #expect(s.toReview[1].reviewRequestedAt == ISO8601DateFormatter().date(from: "2026-11-05T10:00:00Z"))
        #expect(s.mine[0].reviewRequestedAt == nil)
    }

    @Test func reviewRequestToViewerIsYou() throws {
        let review = try reviewJSON(replacingRequests: [["requestedReviewer": ["__typename": "User", "login": "adriano"]]], at: 0)
        let s = try PullRequestMapper.snapshot(mineJSON: fixture("search-mine"), reviewJSON: review, mergedJSON: nil, now: .fixed)
        #expect(s.toReview[0].reviewTarget == .you)
    }

    @Test func reviewRequestOnlyToTeamIsTeamWithName() throws {
        #expect(try snapshot().toReview[1].reviewTarget == .team(name: "backend"))
    }

    @Test func viewerOwnPullRequestRequestedOnlyToTeamIsNotToReview() throws {
        let team: [String: Any] = ["requestedReviewer": ["__typename": "Team", "name": "backend"]]
        let review = try reviewJSON(replacingRequests: [team], at: 1, authorLogin: "Adriano")
        let s = try PullRequestMapper.snapshot(mineJSON: fixture("search-mine"), reviewJSON: review, mergedJSON: nil, now: .fixed)
        #expect(s.toReview.map(\.id) == ["PR_201"])
    }

    @Test func viewerAndTeamBothRequestedIsYou() throws {
        let s = try snapshot()
        #expect(s.toReview[0].reviewTarget == .you)
        #expect(s.toReview[0].reviewRequestedAt == ISO8601DateFormatter().date(from: "2026-11-05T09:30:00Z"))
    }

    @Test func reviewWithoutPendingRequestIsDropped() throws {
        let review = try reviewJSON(replacingRequests: [], at: 1)
        let s = try PullRequestMapper.snapshot(mineJSON: fixture("search-mine"), reviewJSON: review, mergedJSON: nil, now: .fixed)
        #expect(s.toReview.map(\.id) == ["PR_201"])
    }

    @Test func teamRequestedAtComesFromTeamEvent() throws {
        let pr = try snapshot().toReview[1]
        #expect(pr.reviewRequestedAt == ISO8601DateFormatter().date(from: "2026-11-05T10:00:00Z"))
    }

    @Test func mapsReviewDecision() throws {
        let s = try snapshot()
        #expect(s.toReview[0].reviewDecision == .approved)
        #expect(s.toReview[1].reviewDecision == nil)
        #expect(s.mine[0].reviewDecision == nil)
        #expect(s.mine[0].reviewTarget == .you)
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

    @Test func malformedPullRequestNodeIsSkipped() throws {
        var object = try JSONSerialization.jsonObject(with: fixture("search-mine")) as! [String: Any]
        var data = object["data"] as! [String: Any]
        var search = data["search"] as! [String: Any]
        var nodes = search["nodes"] as! [Any]
        var broken = nodes[0] as! [String: Any]
        broken.removeValue(forKey: "number")
        nodes[0] = broken
        nodes.append([String: Any]())
        search["nodes"] = nodes
        data["search"] = search
        object["data"] = data
        let mine = try JSONSerialization.data(withJSONObject: object)
        let s = try PullRequestMapper.snapshot(mineJSON: mine, reviewJSON: fixture("search-review"), mergedJSON: nil, now: .fixed)
        #expect(s.mine.map(\.id) == ["PR_102", "PR_103", "PR_104"])
    }

    @Test func mapsHeadRefAndForkFlag() throws {
        let s = try snapshot()
        #expect(s.mine[0].headRefName == "feat/branch-101")
        #expect(!s.mine[0].isCrossRepository)
        #expect(s.mine[3].headRefName == "feat/branch-104")
        #expect(s.mine[3].isCrossRepository)
    }

    @Test func mapsBaseRefName() throws {
        let s = try snapshot()
        #expect(s.mine[0].baseRefName == "main")
        #expect(s.mine[3].baseRefName == "develop")
        #expect(s.toReview[0].baseRefName == "main")
    }

    @Test func failedRunIDFromDetailsURL() throws {
        let s = try snapshot()
        #expect(s.mine[1].failedRunID == 102001)
        #expect(s.mine[0].failedRunID == nil)
        #expect(s.mine[3].failedRunID == nil)
    }

    @Test func failedRunIDFromFirstFailingCheckRun() throws {
        let json = String(decoding: try fixture("search-mine"), as: UTF8.self)
            .replacingOccurrences(of: "https://github.com/acme/api/actions/runs/102001/job/1021", with: "https://github.com/globex/web-app/actions/runs/1234567/job/89")
        let s = try PullRequestMapper.snapshot(mineJSON: Data(json.utf8), reviewJSON: fixture("search-review"), mergedJSON: nil, now: .fixed)
        #expect(s.mine[1].failedRunID == 1234567)
    }

    @Test func failedRunIDNilForExternalCI() throws {
        let json = String(decoding: try fixture("search-mine"), as: UTF8.self)
            .replacingOccurrences(of: "https://github.com/acme/api/actions/runs/102001/job/1021", with: "https://ci.example.com/builds/9876")
        let s = try PullRequestMapper.snapshot(mineJSON: Data(json.utf8), reviewJSON: fixture("search-review"), mergedJSON: nil, now: .fixed)
        #expect(s.mine[1].ci == .failure(failedChecks: ["unit-tests"], total: 12))
        #expect(s.mine[1].failedRunID == nil)
    }

    @Test func failedRunNameMatchesRunCheck() throws {
        let json = String(decoding: try fixture("search-mine"), as: UTF8.self)
            .replacingOccurrences(of: "\"nodes\": [\n                        {\n                          \"__typename\": \"CheckRun\",\n                          \"name\": \"unit-tests\"", with: "\"nodes\": [\n                        {\"__typename\": \"StatusContext\", \"context\": \"lint\", \"state\": \"FAILURE\"},\n                        {\n                          \"__typename\": \"CheckRun\",\n                          \"name\": \"unit-tests\"")
            .replacingOccurrences(of: "https://github.com/acme/api/actions/runs/102001/job/1021", with: "https://github.com/acme/loja/actions/runs/555/job/9")
        let s = try PullRequestMapper.snapshot(mineJSON: Data(json.utf8), reviewJSON: fixture("search-review"), mergedJSON: nil, now: .fixed)
        #expect(s.mine[1].ci == .failure(failedChecks: ["lint", "unit-tests"], total: 12))
        #expect(s.mine[1].failedRunID == 555)
        #expect(s.mine[1].failedRunName == "unit-tests")
    }

    @Test func failedRunNameNilForExternalCI() throws {
        let json = String(decoding: try fixture("search-mine"), as: UTF8.self)
            .replacingOccurrences(of: "https://github.com/acme/api/actions/runs/102001/job/1021", with: "https://ci.example.com/builds/9876")
        let s = try PullRequestMapper.snapshot(mineJSON: Data(json.utf8), reviewJSON: fixture("search-review"), mergedJSON: nil, now: .fixed)
        #expect(s.mine[1].failedRunID == nil)
        #expect(s.mine[1].failedRunName == nil)
    }

    @Test func ciIsTerminal() {
        #expect(!CIStatus.none.isTerminal)
        #expect(!CIStatus.pending(done: 1, total: 2).isTerminal)
        #expect(CIStatus.success(total: 2).isTerminal)
        #expect(CIStatus.failure(failedChecks: ["a"], total: 2).isTerminal)
    }

    @Test func reviewSearchUsesReviewRequested() {
        #expect(Queries.review == "is:pr is:open review-requested:@me archived:false")
    }

    @Test func mergedQueryUsesLocalMidnightWithOffset() throws {
        let now = ISO8601DateFormatter().date(from: "2026-11-05T17:00:00Z")!
        let zone = TimeZone(identifier: "America/Sao_Paulo")!
        #expect(Queries.merged(since: now, timeZone: zone) == "is:pr author:@me is:merged merged:>=2026-11-05T00:00:00-03:00 archived:false")
    }

    @Test func mapsMergedPullRequests() throws {
        let s = try PullRequestMapper.snapshot(
            mineJSON: fixture("search-mine"), reviewJSON: fixture("search-review"),
            mergedJSON: fixture("search-merged"), now: .fixed
        )
        #expect(s.mergedToday.map(\.id) == ["PR_900", "PR_901"])
        #expect(s.mergedToday[0].repository == "acme/loja")
        #expect(s.mergedToday[0].number == 900)
        #expect(s.mergedToday[1].mergedAt == ISO8601DateFormatter().date(from: "2026-11-05T15:10:00Z"))
    }
}
