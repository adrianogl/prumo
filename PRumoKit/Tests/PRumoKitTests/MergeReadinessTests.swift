import Foundation
import Testing
@testable import PRumoKit

@Suite struct MergeReadinessTests {
    private func approval(_ author: String = "ana") -> Review {
        Review(id: author, author: author, state: .approved, submittedAt: .fixed)
    }

    private func ready(_ pr: PullRequest) -> Bool {
        MergeReadiness.isReady(pr, viewer: "adriano")
    }

    @Test func readyWhenApprovedGreenAndMergeable() {
        #expect(ready(.fixture(ci: .success(total: 3), mergeable: .mergeable, reviewDecision: .approved)))
    }

    @Test func notReadyWhenPendingCI() {
        #expect(!ready(.fixture(ci: .pending(done: 1, total: 3), reviewDecision: .approved)))
    }

    @Test func notReadyWhenCIFailed() {
        #expect(!ready(.fixture(ci: .failure(failedChecks: ["x"], total: 3), reviewDecision: .approved)))
    }

    @Test func noChecksCountsAsGreen() {
        #expect(ready(.fixture(ci: .none, reviewDecision: .approved)))
    }

    @Test func withoutBranchProtectionOneApprovalIsEnough() {
        #expect(ready(.fixture(reviews: [approval()], reviewDecision: nil)))
    }

    @Test func withoutBranchProtectionNeedsAnApproval() {
        #expect(!ready(.fixture(reviews: [], reviewDecision: nil)))
    }

    @Test func withoutBranchProtectionChangesRequestedBlocks() {
        let changes = Review(id: "bia", author: "bia", state: .changesRequested, submittedAt: .fixed)
        #expect(!ready(.fixture(reviews: [approval(), changes], reviewDecision: nil)))
    }

    @Test func reviewRequiredBlocksEvenWithApproval() {
        #expect(!ready(.fixture(reviews: [approval()], reviewDecision: .reviewRequired)))
    }

    @Test func changesRequestedDecisionBlocks() {
        #expect(!ready(.fixture(reviews: [approval()], reviewDecision: .changesRequested)))
    }

    @Test func unknownMergeableIsNotReady() {
        #expect(!ready(.fixture(mergeable: .unknown, reviewDecision: .approved)))
    }

    @Test func conflictingIsNotReady() {
        #expect(!ready(.fixture(mergeable: .conflicting, reviewDecision: .approved)))
    }

    @Test func draftIsNotReady() {
        #expect(!ready(.fixture(isDraft: true, reviewDecision: .approved)))
    }
}
