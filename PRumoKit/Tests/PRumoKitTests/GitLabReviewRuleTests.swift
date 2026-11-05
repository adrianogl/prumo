import Foundation
import Testing
@testable import PRumoKit

@Suite struct GitLabReviewRuleTests {
    private let withState = GitLabCapabilities(hasReviewState: true, hasDetailedMergeStatus: true)
    private let t0 = Date(timeIntervalSince1970: 1_000)
    private let t1 = Date(timeIntervalSince1970: 2_000)
    private let t2 = Date(timeIntervalSince1970: 3_000)

    private func note(_ body: String, at date: Date, system: Bool = true, author: String = "maria", id: String = "n") -> GitLabNote {
        GitLabNote(id: id, body: body, system: system, createdAt: date, url: nil, author: GitLabUser(username: author, bot: nil))
    }

    @Test func pendingWhileUnreviewed() {
        #expect(GitLabReviewRule.isPending(reviewState: "UNREVIEWED", approvedByMe: false, myLastCommentAt: nil, requestedAt: t0, capabilities: withState))
    }

    @Test func leavesWhenApproved() {
        #expect(!GitLabReviewRule.isPending(reviewState: "UNREVIEWED", approvedByMe: true, myLastCommentAt: nil, requestedAt: t0, capabilities: withState))
    }

    @Test func leavesWhenStateNotUnreviewed() {
        for state in ["REVIEWED", "REQUESTED_CHANGES"] {
            #expect(!GitLabReviewRule.isPending(reviewState: state, approvedByMe: false, myLastCommentAt: nil, requestedAt: t0, capabilities: withState))
        }
    }

    @Test func leavesWhenReviewStartedOrApprovedState() {
        for state in ["REVIEW_STARTED", "APPROVED"] {
            #expect(!GitLabReviewRule.isPending(reviewState: state, approvedByMe: false, myLastCommentAt: nil, requestedAt: t0, capabilities: withState))
        }
    }

    @Test func returnsWhenReRequested() {
        #expect(!GitLabReviewRule.isPending(reviewState: "REVIEWED", approvedByMe: false, myLastCommentAt: nil, requestedAt: t0, capabilities: withState))
        #expect(GitLabReviewRule.isPending(reviewState: "UNREVIEWED", approvedByMe: false, myLastCommentAt: t1, requestedAt: t2, capabilities: withState))
    }

    @Test func withoutStateLeavesOnCommentAfterRequest() {
        #expect(!GitLabReviewRule.isPending(reviewState: nil, approvedByMe: false, myLastCommentAt: t1, requestedAt: t0, capabilities: .minimal))
    }

    @Test func withoutStateCommentBeforeRequestKeeps() {
        #expect(GitLabReviewRule.isPending(reviewState: nil, approvedByMe: false, myLastCommentAt: t0, requestedAt: t1, capabilities: .minimal))
        #expect(GitLabReviewRule.isPending(reviewState: nil, approvedByMe: false, myLastCommentAt: nil, requestedAt: t1, capabilities: .minimal))
    }

    @Test func withoutStateReRequestAfterCommentReturns() {
        #expect(!GitLabReviewRule.isPending(reviewState: nil, approvedByMe: false, myLastCommentAt: t1, requestedAt: t0, capabilities: .minimal))
        #expect(GitLabReviewRule.isPending(reviewState: nil, approvedByMe: false, myLastCommentAt: t1, requestedAt: t2, capabilities: .minimal))
    }

    @Test func requestedAtFromSystemNote() {
        let notes = [note("requested review from @maria and @adriano", at: t1)]
        #expect(ReviewRequestNote.requestedAt(notes: notes, username: "adriano") == t1)
    }

    @Test func requestedAtUsesLatestRequest() {
        let notes = [
            note("requested review from @adriano", at: t2),
            note("requested review from @adriano", at: t1)
        ]
        #expect(ReviewRequestNote.requestedAt(notes: notes, username: "ADRIANO") == t2)
    }

    @Test func requestedAtIgnoresSimilarUsername() {
        let notes = [
            note("requested review from @adriano.silva", at: t1),
            note("requested review from @adriano2", at: t1),
            note("requested review from @adriano-x and @adriano_y", at: t1)
        ]
        #expect(ReviewRequestNote.requestedAt(notes: notes, username: "adriano") == nil)
    }

    @Test func requestedAtIgnoresUserNotes() {
        let notes = [note("requested review from @adriano", at: t1, system: false)]
        #expect(ReviewRequestNote.requestedAt(notes: notes, username: "adriano") == nil)
    }

    @Test func requestedAtNilWithoutNote() {
        #expect(ReviewRequestNote.requestedAt(notes: [], username: "adriano") == nil)
    }

    @Test func approvedAtFromLatestApproval() {
        let notes = [
            note("approved this merge request", at: t1, author: "adriano"),
            note("approved this merge request", at: t2, author: "adriano"),
            note("approved this merge request", at: t0, author: "maria")
        ]
        #expect(ReviewRequestNote.approvedAt(notes: notes, username: "adriano") == t2)
    }

    @Test func approvedAtNilAfterUnapprove() {
        let notes = [
            note("approved this merge request", at: t0, author: "adriano"),
            note("unapproved this merge request", at: t1, author: "adriano")
        ]
        #expect(ReviewRequestNote.approvedAt(notes: notes, username: "adriano") == nil)
    }

    @Test func approvedAtKeptWhenUnapproveWasBefore() {
        let notes = [
            note("unapproved this merge request", at: t0, author: "adriano"),
            note("approved this merge request", at: t1, author: "adriano"),
            note("unapproved this merge request", at: t2, author: "maria")
        ]
        #expect(ReviewRequestNote.approvedAt(notes: notes, username: "adriano") == t1)
    }

    @Test func changesRequestedAtFromLatest() {
        let notes = [
            note("requested changes", at: t1, author: "adriano"),
            note("requested changes", at: t2, author: "adriano"),
            note("requested changes", at: t0, author: "maria")
        ]
        #expect(ReviewRequestNote.changesRequestedAt(notes: notes, username: "adriano") == t2)
    }

    @Test func noteDecodesFractionalAndPlainDates() throws {
        let json = """
        [{"id":"1","body":"a","system":true,"createdAt":"2026-11-05T22:12:16.747Z","url":null,"author":{"username":"adriano","bot":false}},
         {"id":"2","body":"b","system":false,"createdAt":"2026-11-05T22:06:52Z","url":"https://gitlab.com/x/y/-/merge_requests/1#note_2","author":null}]
        """
        let notes = try JSONDecoder().decode([GitLabNote].self, from: Data(json.utf8))
        #expect(notes[0].createdAt.timeIntervalSince1970 == 1_793_916_736.747)
        #expect(notes[1].createdAt.timeIntervalSince1970 == 1_793_916_412)
        #expect(notes[1].url?.absoluteString == "https://gitlab.com/x/y/-/merge_requests/1#note_2")
        #expect(notes[1].author == nil)
    }

    @Test func capabilitiesDecodeMissingFieldsAsFalse() throws {
        let decoded = try JSONDecoder().decode(GitLabCapabilities.self, from: Data("{}".utf8))
        #expect(decoded == .minimal)
        let partial = try JSONDecoder().decode(GitLabCapabilities.self, from: Data(#"{"hasReviewState":true}"#.utf8))
        #expect(partial.hasReviewState && !partial.hasDetailedMergeStatus)
    }
}
