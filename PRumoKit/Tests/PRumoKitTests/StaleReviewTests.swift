import Foundation
import Testing
@testable import PRumoKit

@Suite struct StaleReviewTests {
    private let hour: TimeInterval = 3600
    private let limit: TimeInterval = 24 * 3600

    private func pr(
        id: String = "PR_1", number: Int = 798, hoursAgo: Double, draft: Bool = false,
        target: ReviewRequestTarget = .you
    ) -> PullRequest {
        .fixture(
            id: id, number: number, isDraft: draft,
            reviewRequestedAt: Date.fixed.addingTimeInterval(-hoursAgo * hour), reviewTarget: target
        )
    }

    private func due(
        _ prs: [PullRequest], reminded: Set<String> = [], muted: Set<String> = [],
        ignoreDrafts: Bool = true, includeTeam: Bool = false
    ) -> [StaleReminder] {
        StaleReviewTracker.due(
            snapshot: .fixture(toReview: prs), limit: limit, reminded: reminded, muted: muted,
            ignoreDrafts: ignoreDrafts, includeTeam: includeTeam, now: .fixed
        )
    }

    @Test func dueAfterLimitOnlyOnce() {
        let stale = pr(hoursAgo: 25)
        let first = due([stale])
        #expect(first.count == 1)
        #expect(first[0].event.kind == .staleReview)
        #expect(first[0].event.url == stale.url)
        #expect(first[0].event.body == "adriano pediu seu review em Corrige cálculo do carrinho")
        #expect(due([stale], reminded: [first[0].key]).isEmpty)
    }

    @Test func notDueBeforeLimit() {
        #expect(due([pr(hoursAgo: 23.9)]).isEmpty)
        #expect(due([pr(hoursAgo: 24)]).count == 1)
    }

    @Test func teamRequestDueWhenIncluded() {
        #expect(due([pr(hoursAgo: 30, target: .team(name: "backend"))], includeTeam: true).count == 1)
    }

    @Test func teamRequestNeverDueWhenExcluded() {
        #expect(due([pr(hoursAgo: 30, target: .team(name: "backend"))], includeTeam: false).isEmpty)
    }

    @Test func mutedNeverDue() {
        #expect(due([pr(hoursAgo: 30)], muted: ["PR_1"]).isEmpty)
    }

    @Test func draftSkippedWhenIgnoring() {
        let draft = pr(hoursAgo: 30, draft: true)
        #expect(due([draft], ignoreDrafts: true).isEmpty)
        #expect(due([draft], ignoreDrafts: false).count == 1)
    }

    @Test func newRequestGetsNewKey() {
        let old = pr(hoursAgo: 48)
        let renewed = pr(hoursAgo: 30)
        #expect(StaleReviewTracker.key(for: old) != StaleReviewTracker.key(for: renewed))
        let reminded: Set<String> = [StaleReviewTracker.key(for: old)]
        #expect(due([renewed], reminded: reminded).count == 1)
    }

    @Test func keyFallsBackToCreatedAt() {
        let pr = PullRequest.fixture(createdAt: Date(timeIntervalSince1970: 1000))
        #expect(StaleReviewTracker.key(for: pr) == "PR_812@1000")
    }

    @Test func titleUsesWholeHours() {
        let result = due([pr(hoursAgo: 26.5)])
        #expect(result[0].event.title == "Review parado há 26h: #798")
    }

    @Test func stateCapsAt500KeepingNewest() {
        var state = ReminderState()
        state.insert((0..<600).map { "k\($0)" })
        state.insert(["k599", "novo"])
        #expect(state.reminded.count == 500)
        #expect(state.reminded.first == "k101")
        #expect(state.reminded.last == "novo")
        #expect(Set(state.reminded).count == 500)
    }

    @Test func stateDecodesOldOrPartialJSON() throws {
        let empty = try JSONDecoder().decode(ReminderState.self, from: Data("{}".utf8))
        #expect(empty == ReminderState())
        let partial = try JSONDecoder().decode(ReminderState.self, from: Data(#"{"reminded":["a"]}"#.utf8))
        #expect(partial.reminded == ["a"] && !partial.initialized)
        let bad = try JSONDecoder().decode(ReminderState.self, from: Data(#"{"initialized":"x","reminded":5}"#.utf8))
        #expect(bad == ReminderState())
    }

    @Test func stateWithoutViewerDecodesNil() throws {
        let state = try JSONDecoder().decode(ReminderState.self, from: Data(#"{"initialized":true,"reminded":["a"]}"#.utf8))
        #expect(state.viewer == nil && state.initialized)
        let withViewer = try JSONDecoder().decode(ReminderState.self, from: Data(#"{"viewer":"bob"}"#.utf8))
        #expect(withViewer.viewer == "bob")
        let data = try JSONEncoder().encode(ReminderState(initialized: true, viewer: "bob"))
        #expect(try JSONDecoder().decode(ReminderState.self, from: data).viewer == "bob")
    }

    @Test func storeRoundTripAndMissingFile() async throws {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appending(path: "reminders.json")
        let store = ReminderStore(fileURL: url)
        #expect(await store.load() == ReminderState())
        var state = ReminderState(initialized: true)
        state.insert(["a@1", "b@2"])
        try await store.save(state)
        #expect(await store.load() == state)
        try Data("lixo".utf8).write(to: url)
        #expect(await store.load() == ReminderState())
    }

    @Test func defaultURLPointsToApplicationSupport() {
        #expect(ReminderStore.defaultURL().path.hasSuffix("Application Support/PRumo/reminders.json"))
    }
}
