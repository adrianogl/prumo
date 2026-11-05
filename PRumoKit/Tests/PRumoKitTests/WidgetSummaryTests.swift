import Foundation
import Testing
@testable import PRumoKit

@Suite struct WidgetSummaryTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let failure = CIStatus.failure(failedChecks: ["build"], total: 3)

    func make(_ snapshot: Snapshot, ignoreDrafts: Bool = true, includeTeam: Bool = true, muted: Set<String> = []) -> WidgetSnapshot {
        WidgetSummary.make(
            snapshot: snapshot, ignoreDrafts: ignoreDrafts, includeTeam: includeTeam, muted: muted,
            staleLimit: 24 * 3600, now: now
        )
    }

    @Test func countsMatchMenuBarRules() {
        let snapshot = Snapshot.fixture(
            mine: [.fixture(id: "M1", ci: failure), .fixture(id: "M2", reviewDecision: .approved)],
            toReview: [
                .fixture(id: "A", number: 1),
                .fixture(id: "B", number: 2, isDraft: true),
                .fixture(id: "C", number: 3, reviewTarget: .team(name: "time"))
            ]
        )
        let withTeam = make(snapshot, includeTeam: true)
        #expect(withTeam.toReview == 2)
        #expect(withTeam.ciFailing == 1)
        #expect(withTeam.readyToMerge == 1)
        #expect(make(snapshot, includeTeam: false).toReview == 1)
        #expect(make(snapshot, ignoreDrafts: false, includeTeam: true).toReview == 3)
    }

    @Test func itemsOrderedCIThenStaleThenReady() {
        let old = now.addingTimeInterval(-50 * 3600)
        let older = now.addingTimeInterval(-80 * 3600)
        let snapshot = Snapshot.fixture(
            mine: [
                .fixture(id: "R", updatedAt: now, reviewDecision: .approved),
                .fixture(id: "F1", updatedAt: now.addingTimeInterval(-10), ci: failure),
                .fixture(id: "F2", updatedAt: now, ci: failure)
            ],
            toReview: [
                .fixture(id: "S1", reviewRequestedAt: old),
                .fixture(id: "S2", reviewRequestedAt: older),
                .fixture(id: "T", reviewRequestedAt: old.addingTimeInterval(-1), reviewTarget: .team(name: "time"))
            ]
        )
        let result = make(snapshot, includeTeam: true, muted: [])
        #expect(result.items.map { $0.id } == ["F2", "F1", "S2"])
        let all = WidgetSummary.make(
            snapshot: Snapshot.fixture(
                mine: [.fixture(id: "R", reviewDecision: .approved), .fixture(id: "F", ci: failure)],
                toReview: [.fixture(id: "S", reviewRequestedAt: old)]
            ),
            ignoreDrafts: true, includeTeam: true, muted: [], staleLimit: 3600, now: now
        )
        #expect(all.items.map(\.reason) == [.ciFailing, .staleReview, .readyToMerge])
    }

    @Test func capsAtThreeItems() {
        let snapshot = Snapshot.fixture(
            mine: (1...5).map { .fixture(id: "F\($0)", number: $0, ci: failure) }
        )
        #expect(make(snapshot).items.count == 3)
        #expect(make(snapshot).ciFailing == 5)
    }

    @Test func mutedNotInItems() {
        let old = now.addingTimeInterval(-50 * 3600)
        let snapshot = Snapshot.fixture(
            mine: [.fixture(id: "F", ci: failure), .fixture(id: "R", reviewDecision: .approved)],
            toReview: [.fixture(id: "S", reviewRequestedAt: old)]
        )
        #expect(make(snapshot, muted: ["F", "R", "S"]).items.isEmpty)
        #expect(make(snapshot, muted: ["F"]).items.map(\.id) == ["S", "R"])
    }

    @Test func staleItemHasWholeHours() {
        let snapshot = Snapshot.fixture(
            toReview: [.fixture(id: "S", reviewRequestedAt: now.addingTimeInterval(-(26 * 3600 + 1800)))]
        )
        let item = make(snapshot).items.first
        #expect(item?.reason == .staleReview)
        #expect(item?.waitingHours == 26)
    }

    @Test func belowStaleLimitIsNotListed() {
        let snapshot = Snapshot.fixture(
            toReview: [.fixture(id: "S", reviewRequestedAt: now.addingTimeInterval(-3600))]
        )
        #expect(make(snapshot).items.isEmpty)
    }

    @Test func linkRoundTrip() {
        let url = URL(string: "https://github.com/acme/loja/pull/812?x=a&b=c")!
        let link = WidgetLink.make(url)
        #expect(link.scheme == "prumo")
        #expect(link.host == "open")
        #expect(WidgetLink.target(from: link) == url)
    }

    @Test func linkRejectsNonGitHubURL() {
        func link(_ target: String) -> URL { WidgetLink.make(URL(string: target)!) }
        #expect(WidgetLink.target(from: link("https://exemplo.com/acme/loja/pull/1")) == nil)
        #expect(WidgetLink.target(from: link("http://github.com/acme/loja/pull/1")) == nil)
        #expect(WidgetLink.target(from: link("https://github.com.evil.com/x")) == nil)
        #expect(WidgetLink.target(from: URL(string: "https://github.com/acme/loja/pull/1")!) == nil)
        #expect(WidgetLink.target(from: URL(string: "prumo://other?url=https%3A%2F%2Fgithub.com%2Fa")!) == nil)
        #expect(WidgetLink.target(from: URL(string: "prumo://open")!) == nil)
    }

    @Test func allowsConfiguredGitLabHost() {
        let url = URL(string: "https://gitlab.empresa.com/grupo/app/-/merge_requests/7")!
        #expect(WidgetLink.target(from: WidgetLink.make(url), allowedHosts: ["github.com", "gitlab.empresa.com"]) == url)
        #expect(WidgetLink.target(from: WidgetLink.make(URL(string: "https://GitLab.Empresa.com/x")!), allowedHosts: ["gitlab.empresa.com"]) != nil)
    }

    @Test func allowsConfiguredHostWithPort() {
        let url = URL(string: "https://gitlab.local:8443/grupo/app/-/merge_requests/7")!
        #expect(WidgetLink.target(from: WidgetLink.make(url), allowedHosts: ["gitlab.local:8443"]) == url)
    }

    @Test func rejectsPortMismatch() {
        let withPort = WidgetLink.make(URL(string: "https://gitlab.local:9000/x")!)
        #expect(WidgetLink.target(from: withPort, allowedHosts: ["gitlab.local:8443"]) == nil)
        #expect(WidgetLink.target(from: withPort, allowedHosts: ["gitlab.local"]) == nil)
        let withoutPort = WidgetLink.make(URL(string: "https://gitlab.local/x")!)
        #expect(WidgetLink.target(from: withoutPort, allowedHosts: ["gitlab.local:8443"]) == nil)
    }

    @Test func rejectsUnconfiguredHost() {
        let link = WidgetLink.make(URL(string: "https://gitlab.outro.com/x")!)
        #expect(WidgetLink.target(from: link, allowedHosts: ["github.com", "gitlab.empresa.com"]) == nil)
    }

    @Test func rejectsLookalikeHost() {
        let allowed: Set<String> = ["gitlab.empresa.com"]
        for target in ["https://gitlab.empresa.com.evil.io/x", "https://evilgitlab.empresa.com/x"] {
            #expect(WidgetLink.target(from: WidgetLink.make(URL(string: target)!), allowedHosts: allowed) == nil)
        }
    }

    @Test func rejectsHttp() {
        let link = WidgetLink.make(URL(string: "http://gitlab.empresa.com/x")!)
        #expect(WidgetLink.target(from: link, allowedHosts: ["gitlab.empresa.com"]) == nil)
    }

    @Test func githubStillAllowedByDefault() {
        let url = URL(string: "https://github.com/acme/loja/pull/1")!
        #expect(WidgetLink.target(from: WidgetLink.make(url)) == url)
        #expect(WidgetLink.target(from: WidgetLink.make(URL(string: "https://gitlab.empresa.com/x")!)) == nil)
    }

    @Test func summaryCarriesBangReference() {
        let snapshot = Snapshot.fixture(mine: [.fixture(id: "M1", number: 7, ci: failure, provider: .gitlab)])
        #expect(make(snapshot).items.first?.reference == "!7")
    }

    @Test func oldWidgetJSONDecodes() throws {
        let decoded = try JSONDecoder().decode(WidgetSnapshot.self, from: Data(#"{"toReview":3}"#.utf8))
        #expect(decoded.connected == true)
        #expect(decoded.toReview == 3)
        #expect(decoded.items == [])
    }

    @Test func encodeDecodeRoundTrip() throws {
        let original = WidgetSnapshot(
            connected: true, toReview: 2, ciFailing: 1, readyToMerge: 1,
            items: [WidgetItem(id: "A", number: 1, title: "t", url: URL(string: "https://github.com/a/b/pull/1")!, reason: .staleReview, waitingHours: 30)],
            updatedAt: now
        )
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(WidgetSnapshot.self, from: data) == original)
        #expect(WidgetSnapshot.disconnected.connected == false)
    }

    @Test func widgetSummaryUsesViewerOfEachAccount() {
        let ownApproval = Review(id: "R1", author: "adriano-globex", state: .approved, submittedAt: .fixed)
        let snapshot = Snapshot.fixture(
            viewer: "adrianogl",
            mine: [.fixture(id: "PR_1", reviews: [ownApproval], accountID: "a2")],
            accountViewers: ["a1": "adrianogl", "a2": "adriano-globex"]
        )
        let summary = make(snapshot)
        #expect(summary.readyToMerge == 0)
        #expect(summary.items.isEmpty)
    }
}
