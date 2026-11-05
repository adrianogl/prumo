import Foundation
import Testing
@testable import PRumoKit

@Suite struct WidgetPublishDecisionTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let renewAfter: TimeInterval = 1800

    func snapshot(toReview: Int = 1, updatedAt: Date) -> WidgetSnapshot {
        WidgetSnapshot(toReview: toReview, updatedAt: updatedAt)
    }

    func decide(_ new: WidgetSnapshot, last: WidgetSnapshot?) -> WidgetPublishDecision {
        WidgetPublishDecision.make(new: new, lastPublished: last, now: now, renewAfter: renewAfter)
    }

    @Test func firstPublishWritesAndReloads() {
        let decision = decide(snapshot(updatedAt: now), last: nil)
        #expect(decision == WidgetPublishDecision(write: true, reload: true))
    }

    @Test func changedContentWritesAndReloads() {
        let last = snapshot(toReview: 1, updatedAt: now.addingTimeInterval(-60))
        let decision = decide(snapshot(toReview: 2, updatedAt: now), last: last)
        #expect(decision == WidgetPublishDecision(write: true, reload: true))
    }

    @Test func sameContentRecentDoesNothing() {
        let last = snapshot(updatedAt: now.addingTimeInterval(-600))
        let decision = decide(snapshot(updatedAt: now), last: last)
        #expect(decision == WidgetPublishDecision(write: false, reload: false))
    }

    @Test func sameContentAtExactLimitDoesNothing() {
        let last = snapshot(updatedAt: now.addingTimeInterval(-renewAfter))
        let decision = decide(snapshot(updatedAt: now), last: last)
        #expect(decision == WidgetPublishDecision(write: false, reload: false))
    }

    @Test func sameContentOldRewritesWithoutReload() {
        let last = snapshot(updatedAt: now.addingTimeInterval(-renewAfter - 1))
        let decision = decide(snapshot(updatedAt: now), last: last)
        #expect(decision == WidgetPublishDecision(write: true, reload: false))
    }

    @Test func changedContentOldStillReloads() {
        let last = snapshot(toReview: 1, updatedAt: now.addingTimeInterval(-7200))
        let decision = decide(snapshot(toReview: 0, updatedAt: now), last: last)
        #expect(decision == WidgetPublishDecision(write: true, reload: true))
    }
}
