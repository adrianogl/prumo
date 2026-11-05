import Foundation
import Testing
@testable import PRumoKit

struct ActivityTrackerTests {
    private func event(_ id: String) -> NotificationEvent {
        NotificationEvent(
            kind: .newComment, pullRequestID: id, title: "t", body: "b",
            url: URL(string: "https://github.com/acme/loja/pull/1")!
        )
    }

    @Test func eventsMarkActivity() {
        let old = Snapshot.fixture(mine: [.fixture(id: "a"), .fixture(id: "b")])
        let touched = ActivityTracker.touched(old: old, new: old, events: [event("b")])
        #expect(touched == ["b"])
    }

    @Test func newCommitMarksActivity() {
        let old = Snapshot.fixture(mine: [.fixture(id: "a", headSHA: "111")], toReview: [.fixture(id: "r", headSHA: "222")])
        let new = Snapshot.fixture(mine: [.fixture(id: "a", headSHA: "999")], toReview: [.fixture(id: "r", headSHA: "222")])
        #expect(ActivityTracker.touched(old: old, new: new, events: []) == ["a"])
    }

    @Test func emptyPreviousSHADoesNotMark() {
        let old = Snapshot.fixture(mine: [.fixture(id: "a", headSHA: "")])
        let new = Snapshot.fixture(mine: [.fixture(id: "a", headSHA: "999")])
        #expect(ActivityTracker.touched(old: old, new: new, events: []).isEmpty)
    }

    @Test func titleChangeDoesNotMark() {
        let old = Snapshot.fixture(mine: [.fixture(id: "a", title: "antigo", headSHA: "111")])
        let new = Snapshot.fixture(mine: [.fixture(id: "a", title: "novo", updatedAt: Date(timeIntervalSince1970: 9_999), headSHA: "111")])
        #expect(ActivityTracker.touched(old: old, new: new, events: []).isEmpty)
    }

    @Test func firstSnapshotMarksNothing() {
        let new = Snapshot.fixture(mine: [.fixture(id: "a")])
        #expect(ActivityTracker.touched(old: nil, new: new, events: [event("a")]).isEmpty)
    }

    @Test func prunesIdsNoLongerListed() {
        let snapshot = Snapshot.fixture(mine: [.fixture(id: "a")], toReview: [.fixture(id: "r")])
        #expect(ActivityTracker.pruned(["a", "r", "gone"], snapshot: snapshot) == ["a", "r"])
    }
}
