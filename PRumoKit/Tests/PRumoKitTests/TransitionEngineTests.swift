import Foundation
import Testing
@testable import PRumoKit

@testable import struct PRumoKit.Comment
private typealias PRComment = Comment
private let t0 = Date.fixed
private let t1 = t0.addingTimeInterval(60)
private let t2 = t0.addingTimeInterval(120)

private func comment(_ id: String, author: String = "maria", bot: Bool = false, body: String = "ok", at: Date = t1) -> PRComment {
    PRComment(id: id, author: author, authorIsBot: bot, body: body, url: URL(string: "https://github.com/acme/loja/pull/812#\(id)")!, createdAt: at)
}

private func review(_ id: String, author: String = "maria", bot: Bool = false, state: ReviewState, body: String = "", at: Date = t1) -> Review {
    Review(
        id: id, author: author, authorIsBot: bot, state: state, submittedAt: at, body: body,
        url: URL(string: "https://github.com/acme/loja/pull/812#pullrequestreview-\(id)")!
    )
}

@Suite struct TransitionEngineTests {
    @Test func firstSnapshotEmitsNothing() {
        let new = Snapshot.fixture(mine: [.fixture(ci: .success(total: 3))], toReview: [.fixture(id: "PR_9", number: 9)])
        #expect(TransitionEngine.events(from: nil, to: new).isEmpty)
    }

    @Test func accountSwitchEmitsNothing() {
        let old = Snapshot.fixture(viewer: "adriano", mine: [.fixture(ci: .pending(done: 1, total: 3))])
        let new = Snapshot.fixture(
            viewer: "maria",
            mine: [.fixture(ci: .failure(failedChecks: ["lint"], total: 3), comments: [comment("c1", author: "joao")])],
            toReview: [.fixture(id: "PR_9", number: 9)],
            fetchedAt: t1
        )
        #expect(TransitionEngine.events(from: old, to: new).isEmpty)
    }

    @Test func ciPendingToFailureEmitsOneEventWithChecksURL() {
        let old = Snapshot.fixture(mine: [.fixture(number: 809, ci: .pending(done: 1, total: 3))])
        let new = Snapshot.fixture(
            mine: [.fixture(number: 809, ci: .failure(failedChecks: ["unit-tests", "lint"], total: 3))],
            fetchedAt: t1
        )
        let events = TransitionEngine.events(from: old, to: new)
        #expect(events.count == 1)
        #expect(events[0].kind == .ciFailed)
        #expect(events[0].title == "CI falhou em #809")
        #expect(events[0].body == "Corrige cálculo do carrinho · unit-tests")
        #expect(events[0].url.absoluteString == "https://github.com/acme/loja/pull/812/checks")
        #expect(events[0].threadID == "PR_812")
    }

    @Test func ciFailedEventCarriesRunID() {
        let old = Snapshot.fixture(mine: [.fixture(ci: .pending(done: 1, total: 3))])
        let new = Snapshot.fixture(
            mine: [.fixture(ci: .failure(failedChecks: ["unit-tests"], total: 3), failedRunID: 555, failedRunName: "unit-tests")],
            fetchedAt: t1
        )
        let events = TransitionEngine.events(from: old, to: new)
        #expect(events.count == 1)
        #expect(events[0].failedRunID == 555)
    }

    @Test func ciSucceededEventHasNoRunID() {
        let old = Snapshot.fixture(mine: [.fixture(ci: .pending(done: 11, total: 12))])
        let new = Snapshot.fixture(mine: [.fixture(ci: .success(total: 12), failedRunID: 555)], fetchedAt: t1)
        let events = TransitionEngine.events(from: old, to: new)
        #expect(events.count == 1)
        #expect(events[0].failedRunID == nil)
    }

    @Test func ciSuccessUsesTotalInTitle() {
        let old = Snapshot.fixture(mine: [.fixture(ci: .pending(done: 11, total: 12))])
        let new = Snapshot.fixture(mine: [.fixture(ci: .success(total: 12))], fetchedAt: t1)
        let events = TransitionEngine.events(from: old, to: new)
        #expect(events.count == 1)
        #expect(events[0].kind == .ciSucceeded)
        #expect(events[0].title == "CI terminou em #812: 12/12")
        #expect(events[0].body == "Corrige cálculo do carrinho")
        #expect(events[0].url.absoluteString.hasSuffix("/checks"))
    }

    @Test func ciNoneNeverNotifies() {
        let old = Snapshot.fixture(mine: [.fixture(ci: .pending(done: 0, total: 1))])
        let new = Snapshot.fixture(mine: [.fixture(ci: .none)], fetchedAt: t1)
        #expect(TransitionEngine.events(from: old, to: new).isEmpty)
        let sameNone = Snapshot.fixture(mine: [.fixture(headSHA: "bbb222", ci: .none)], fetchedAt: t2)
        #expect(TransitionEngine.events(from: new, to: sameNone).isEmpty)
    }

    @Test func newPushWhilePendingNotifiesOnlyLatestSHAOnce() {
        let s1 = Snapshot.fixture(mine: [.fixture(headSHA: "A", ci: .pending(done: 1, total: 3))])
        let s2 = Snapshot.fixture(mine: [.fixture(headSHA: "B", ci: .success(total: 3))], fetchedAt: t1)
        let s3 = Snapshot.fixture(mine: [.fixture(headSHA: "B", ci: .success(total: 3))], fetchedAt: t2)
        let first = TransitionEngine.events(from: s1, to: s2)
        #expect(first.count == 1)
        #expect(first[0].kind == .ciSucceeded)
        #expect(first[0].title == "CI terminou em #812: 3/3")
        #expect(TransitionEngine.events(from: s2, to: s3).isEmpty)
    }

    @Test func approvalFromOtherUserNotifies() {
        let old = Snapshot.fixture(mine: [.fixture(number: 812)])
        let new = Snapshot.fixture(
            mine: [.fixture(number: 812, reviews: [
                review("r1", author: "maria", state: .approved),
                review("r2", author: "joao", state: .changesRequested),
                review("r3", author: "ana", state: .commented),
                review("r4", author: "adriano", state: .approved)
            ])],
            fetchedAt: t2
        )
        let events = TransitionEngine.events(from: old, to: new)
        #expect(events.map(\.kind) == [.approved, .changesRequested])
        #expect(events[0].title == "#812 aprovado")
        #expect(events[0].body == "maria aprovou Corrige cálculo do carrinho")
        #expect(events[0].url.absoluteString == "https://github.com/acme/loja/pull/812")
        #expect(events[1].title == "Alterações pedidas em #812")
        #expect(events[1].body == "joao pediu alterações em Corrige cálculo do carrinho")
    }

    @Test func ownCommentAndBotCommentAreIgnored() {
        let old = Snapshot.fixture(mine: [.fixture()])
        let new = Snapshot.fixture(
            mine: [.fixture(comments: [
                comment("c1", author: "adriano"),
                comment("c2", author: "dependabot", bot: true)
            ])],
            fetchedAt: t2
        )
        #expect(TransitionEngine.events(from: old, to: new).isEmpty)
    }

    @Test func singleNewCommentUsesCommentURLAndQuotedBody() {
        let old = Snapshot.fixture(mine: [.fixture()])
        let new = Snapshot.fixture(mine: [.fixture(comments: [comment("c1", body: "Faltou\ntestar")])], fetchedAt: t2)
        let events = TransitionEngine.events(from: old, to: new)
        #expect(events.count == 1)
        #expect(events[0].kind == .newComment)
        #expect(events[0].title == "Comentário novo em #812")
        #expect(events[0].body == "maria: \"Faltou testar\"")
        #expect(events[0].url.absoluteString == "https://github.com/acme/loja/pull/812#c1")
    }

    @Test func multipleNewCommentsBecomeOneEvent() {
        let old = Snapshot.fixture(mine: [.fixture()])
        let long = String(repeating: "x", count: 100)
        let new = Snapshot.fixture(
            mine: [.fixture(comments: [
                comment("c1", author: "maria", at: t1),
                comment("c2", author: "joao", at: t1.addingTimeInterval(10)),
                comment("c3", author: "ana", body: long, at: t1.addingTimeInterval(20))
            ])],
            fetchedAt: t2
        )
        let events = TransitionEngine.events(from: old, to: new)
        #expect(events.count == 1)
        #expect(events[0].title == "3 comentários novos em #812")
        #expect(events[0].body == "ana: \"\(String(repeating: "x", count: 80))…\"")
        #expect(events[0].url.absoluteString == "https://github.com/acme/loja/pull/812#c3")
    }

    @Test func ignoredCommentAuthorsDoNotNotify() {
        let old = Snapshot.fixture(mine: [.fixture()])
        let new = Snapshot.fixture(
            mine: [.fixture(
                reviews: [review("r1", author: "Datadog-Official", state: .commented, body: "Relatório")],
                comments: [comment("c1", author: "github-actions[bot]"), comment("c2", author: "ana", body: "Veja isso")]
            )],
            fetchedAt: t2
        )
        let options = TransitionOptions(ignoredCommentAuthors: ["github-actions", "datadog-official"])
        let events = TransitionEngine.events(from: old, to: new, options: options)
        #expect(events.count == 1)
        #expect(events[0].title == "Comentário novo em #812")
        #expect(events[0].body == "ana: \"Veja isso\"")
    }

    @Test func onlyIgnoredCommentAuthorsEmitNothing() {
        let old = Snapshot.fixture(mine: [.fixture()])
        let new = Snapshot.fixture(mine: [.fixture(comments: [comment("c1", author: "GitHub-Actions")])], fetchedAt: t2)
        let options = TransitionOptions(ignoredCommentAuthors: ["github-actions"])
        #expect(TransitionEngine.events(from: old, to: new, options: options).isEmpty)
    }

    @Test func removingAuthorFromListDoesNotReplayKnownComments() {
        let pr = PullRequest.fixture(comments: [comment("c1", author: "github-actions")], commentCount: 1)
        let old = Snapshot.fixture(mine: [pr], fetchedAt: t0)
        let new = Snapshot.fixture(mine: [pr], fetchedAt: t2)
        #expect(TransitionEngine.events(from: old, to: new, options: TransitionOptions(ignoredCommentAuthors: [])).isEmpty)
    }

    @Test func commentedReviewWithBodyNotifiesAsComment() {
        let old = Snapshot.fixture(mine: [.fixture()])
        let new = Snapshot.fixture(
            mine: [.fixture(reviews: [review("r1", author: "joao", state: .commented, body: "Dá para\nextrair?")])],
            fetchedAt: t2
        )
        let events = TransitionEngine.events(from: old, to: new)
        #expect(events.count == 1)
        #expect(events[0].kind == .newComment)
        #expect(events[0].title == "Comentário novo em #812")
        #expect(events[0].body == "joao: \"Dá para extrair?\"")
        #expect(events[0].url.absoluteString == "https://github.com/acme/loja/pull/812#pullrequestreview-r1")
    }

    @Test func commentedReviewGroupsWithIssueCommentsAndLatestDrivesBody() {
        let old = Snapshot.fixture(mine: [.fixture()])
        let new = Snapshot.fixture(
            mine: [.fixture(
                reviews: [review("r1", author: "joao", state: .commented, body: "Revisei", at: t1.addingTimeInterval(30))],
                comments: [comment("c1", author: "maria", at: t1)]
            )],
            fetchedAt: t2
        )
        let events = TransitionEngine.events(from: old, to: new)
        #expect(events.map(\.kind) == [.newComment])
        #expect(events[0].title == "2 comentários novos em #812")
        #expect(events[0].body == "joao: \"Revisei\"")
        #expect(events[0].url.absoluteString == "https://github.com/acme/loja/pull/812#pullrequestreview-r1")
    }

    @Test func commentedReviewWithoutBodyOwnOrBotIsIgnored() {
        let old = Snapshot.fixture(mine: [.fixture(reviews: [review("r0", author: "joao", state: .commented, body: "antigo")])])
        let new = Snapshot.fixture(
            mine: [.fixture(reviews: [
                review("r0", author: "joao", state: .commented, body: "antigo"),
                review("r1", author: "joao", state: .commented, body: "  \n"),
                review("r2", author: "adriano", state: .commented, body: "meu"),
                review("r3", author: "copilot", bot: true, state: .commented, body: "sugestão"),
                review("r4", author: "ana", state: .commented, body: "velho", at: t0.addingTimeInterval(-3600))
            ])],
            fetchedAt: t2
        )
        #expect(TransitionEngine.events(from: old, to: new).isEmpty)
    }

    @Test func commentedReviewWithoutURLFallsBackToPullRequestURL() {
        let old = Snapshot.fixture(mine: [.fixture()])
        let new = Snapshot.fixture(
            mine: [.fixture(reviews: [Review(id: "r1", author: "joao", state: .commented, submittedAt: t1, body: "ok")])],
            fetchedAt: t2
        )
        #expect(TransitionEngine.events(from: old, to: new).map(\.url.absoluteString) == ["https://github.com/acme/loja/pull/812"])
    }

    @Test func prThatDisappearsAndReturnsDoesNotReplayHistory() {
        let withPR = Snapshot.fixture(mine: [.fixture(comments: [comment("c1", at: t0)])], fetchedAt: t0)
        let without = Snapshot.fixture(mine: [], fetchedAt: t1)
        let back = Snapshot.fixture(
            mine: [.fixture(
                reviews: [review("r1", state: .approved, at: t0)],
                comments: [comment("c1", at: t0), comment("c0", at: t0.addingTimeInterval(-3600))]
            )],
            fetchedAt: t2
        )
        #expect(TransitionEngine.events(from: without, to: back).isEmpty)
        let staleHistory = Snapshot.fixture(
            mine: [.fixture(
                reviews: [review("r1", state: .approved, at: t0.addingTimeInterval(-300))],
                comments: [comment("c1", at: t0.addingTimeInterval(-300)), comment("c0", at: t0.addingTimeInterval(-3600))],
                reviewDecision: .reviewRequired
            )],
            fetchedAt: t2
        )
        let base = Snapshot.fixture(mine: [.fixture()], fetchedAt: t1)
        #expect(TransitionEngine.events(from: base, to: staleHistory).isEmpty)
        #expect(TransitionEngine.events(from: withPR, to: without).isEmpty)
    }

    @Test func newReviewRequestNotifies() {
        let old = Snapshot.fixture(toReview: [.fixture(id: "PR_1", number: 1)])
        let new = Snapshot.fixture(
            toReview: [
                .fixture(id: "PR_1", number: 1),
                .fixture(id: "PR_815", number: 815, title: "Ajusta frete", url: URL(string: "https://github.com/acme/loja/pull/815")!, author: "carla")
            ],
            fetchedAt: t1
        )
        let events = TransitionEngine.events(from: old, to: new)
        #expect(events.count == 1)
        #expect(events[0].kind == .reviewRequested)
        #expect(events[0].title == "Review pedido: #815")
        #expect(events[0].body == "carla pediu seu review em Ajusta frete")
        #expect(events[0].url.absoluteString == "https://github.com/acme/loja/pull/815")
        #expect(events[0].threadID == "PR_815")
    }

    @Test func eventsAfterLongOfflineGapNotifyOnce() {
        let old = Snapshot.fixture(mine: [.fixture(headSHA: "A", ci: .pending(done: 1, total: 2))], fetchedAt: t0)
        let later = t0.addingTimeInterval(8 * 3600)
        let new = Snapshot.fixture(
            mine: [.fixture(
                headSHA: "A", ci: .failure(failedChecks: ["unit-tests"], total: 2),
                reviews: [review("r1", state: .approved, at: t0.addingTimeInterval(3600))],
                comments: [
                    comment("c1", at: t0.addingTimeInterval(1800)),
                    comment("c2", at: t0.addingTimeInterval(7200))
                ]
            )],
            fetchedAt: later
        )
        let events = TransitionEngine.events(from: old, to: new)
        #expect(events.map(\.kind) == [.ciFailed, .approved, .newComment])
        #expect(events[2].title == "2 comentários novos em #812")
        let again = Snapshot.fixture(mine: new.mine, fetchedAt: later.addingTimeInterval(60))
        #expect(TransitionEngine.events(from: new, to: again).isEmpty)
    }

    @Test func eventOrderFollowsMineThenToReview() {
        let old = Snapshot.fixture(
            mine: [.fixture(id: "A", number: 1, ci: .pending(done: 0, total: 1)), .fixture(id: "B", number: 2, ci: .pending(done: 0, total: 1))],
            toReview: []
        )
        let new = Snapshot.fixture(
            mine: [.fixture(id: "A", number: 1, ci: .success(total: 1)), .fixture(id: "B", number: 2, ci: .success(total: 1))],
            toReview: [.fixture(id: "C", number: 3)],
            fetchedAt: t1
        )
        #expect(TransitionEngine.events(from: old, to: new).map(\.pullRequestID) == ["A", "B", "C"])
    }

    @Test func approvedComesBeforeChangesRequestedRegardlessOfReviewOrder() {
        let old = Snapshot.fixture(mine: [.fixture()])
        let new = Snapshot.fixture(
            mine: [.fixture(reviews: [
                review("r1", author: "joao", state: .changesRequested),
                review("r2", author: "maria", state: .approved)
            ])],
            fetchedAt: t2
        )
        #expect(TransitionEngine.events(from: old, to: new).map(\.kind) == [.approved, .changesRequested])
    }

    @Test func commentCreatedJustBeforeOldFetchStillNotifies() {
        let old = Snapshot.fixture(mine: [.fixture()], fetchedAt: t1)
        let new = Snapshot.fixture(
            mine: [.fixture(comments: [comment("c1", at: t1.addingTimeInterval(-60))])],
            fetchedAt: t2
        )
        let events = TransitionEngine.events(from: old, to: new)
        #expect(events.count == 1)
        #expect(events[0].kind == .newComment)
        #expect(events[0].title == "Comentário novo em #812")
    }

    @Test func staleReviewRequestReturningToListEmitsNothing() {
        let old = Snapshot.fixture(toReview: [], fetchedAt: t2)
        let new = Snapshot.fixture(
            toReview: [.fixture(id: "PR_815", number: 815, reviewRequestedAt: t0)],
            fetchedAt: t2.addingTimeInterval(60)
        )
        #expect(TransitionEngine.events(from: old, to: new).isEmpty)
    }

    @Test func teamRequestNotifiesWhenIncluded() {
        let old = Snapshot.fixture(toReview: [])
        let new = Snapshot.fixture(toReview: [.fixture(id: "PR_7", number: 7, reviewTarget: .team(name: "time"))], fetchedAt: t1)
        let events = TransitionEngine.events(from: old, to: new, options: TransitionOptions(includeTeamRequests: true))
        #expect(events.map(\.kind) == [.reviewRequested])
        #expect(events[0].pullRequestID == "PR_7")
    }

    @Test func teamRequestSilentWhenExcluded() {
        let old = Snapshot.fixture(toReview: [])
        let new = Snapshot.fixture(toReview: [.fixture(id: "PR_7", number: 7, reviewTarget: .team(name: "time"))], fetchedAt: t1)
        #expect(TransitionEngine.events(from: old, to: new, options: TransitionOptions(includeTeamRequests: false)).isEmpty)
    }

    @Test func togglingTeamOptionDoesNotBurst() {
        let pr = PullRequest.fixture(id: "PR_7", number: 7, reviewRequestedAt: t0, reviewTarget: .team(name: "time"))
        let old = Snapshot.fixture(toReview: [pr], fetchedAt: t2)
        let new = Snapshot.fixture(toReview: [pr], fetchedAt: t2.addingTimeInterval(60))
        #expect(TransitionEngine.events(from: old, to: new, options: TransitionOptions(includeTeamRequests: true)).isEmpty)
    }

    @Test func teamRequestBecomingDirectNotifies() {
        let old = Snapshot.fixture(toReview: [.fixture(id: "PR_7", number: 7, reviewRequestedAt: t0, reviewTarget: .team(name: "time"))], fetchedAt: t2)
        let new = Snapshot.fixture(
            toReview: [.fixture(id: "PR_7", number: 7, reviewRequestedAt: t0, reviewTarget: .you)],
            fetchedAt: t2.addingTimeInterval(60)
        )
        let events = TransitionEngine.events(from: old, to: new, options: TransitionOptions(includeTeamRequests: false))
        #expect(events.map(\.kind) == [.reviewRequested])
        #expect(events[0].pullRequestID == "PR_7")
    }

    @Test func draftReviewRequestIgnoredWhenOptionOn() {
        let old = Snapshot.fixture(toReview: [])
        let new = Snapshot.fixture(toReview: [.fixture(id: "PR_8", number: 8, isDraft: true)], fetchedAt: t1)
        #expect(TransitionEngine.events(from: old, to: new, options: .init(ignoreDraftReviews: true)).isEmpty)
    }

    @Test func draftReviewRequestNotifiesWhenOptionOff() {
        let old = Snapshot.fixture(toReview: [])
        let new = Snapshot.fixture(toReview: [.fixture(id: "PR_8", number: 8, isDraft: true)], fetchedAt: t1)
        let events = TransitionEngine.events(from: old, to: new, options: .init(ignoreDraftReviews: false))
        #expect(events.map(\.kind) == [.reviewRequested])
    }

    @Test func draftBecomingReadyNotifiesWhenIgnoringDrafts() {
        let old = Snapshot.fixture(toReview: [.fixture(id: "PR_8", number: 8, isDraft: true, reviewRequestedAt: t0)], fetchedAt: t2)
        let new = Snapshot.fixture(
            toReview: [.fixture(id: "PR_8", number: 8, isDraft: false, reviewRequestedAt: t0)],
            fetchedAt: t2.addingTimeInterval(60)
        )
        let events = TransitionEngine.events(from: old, to: new, options: .init(ignoreDraftReviews: true))
        #expect(events.map(\.kind) == [.reviewRequested])
        let again = Snapshot.fixture(toReview: new.toReview, fetchedAt: t2.addingTimeInterval(120))
        #expect(TransitionEngine.events(from: new, to: again, options: .init(ignoreDraftReviews: true)).isEmpty)
    }

    @Test func enteringConflictNotifies() {
        let old = Snapshot.fixture(mine: [.fixture(number: 812, mergeable: .mergeable)])
        let new = Snapshot.fixture(mine: [.fixture(number: 812, mergeable: .conflicting)], fetchedAt: t1)
        let events = TransitionEngine.events(from: old, to: new)
        #expect(events.map(\.kind) == [.conflict])
        #expect(events.first?.title == "#812 entrou em conflito")
        #expect(events.first?.body == "Corrige cálculo do carrinho · conflito com main")
        #expect(events.first?.url == URL(string: "https://github.com/acme/loja/pull/812"))
    }

    @Test func conflictBodyWithoutBaseIsTitle() {
        let old = Snapshot.fixture(mine: [.fixture(mergeable: .mergeable)])
        let new = Snapshot.fixture(mine: [.fixture(mergeable: .conflicting, baseRefName: "")], fetchedAt: t1)
        #expect(TransitionEngine.events(from: old, to: new).first?.body == "Corrige cálculo do carrinho")
    }

    @Test func staysConflictingDoesNotRenotify() {
        let old = Snapshot.fixture(mine: [.fixture(mergeable: .conflicting)])
        let new = Snapshot.fixture(mine: [.fixture(mergeable: .conflicting)], fetchedAt: t1)
        #expect(TransitionEngine.events(from: old, to: new).isEmpty)
    }

    @Test func becomingReadyNotifiesOnce() {
        let old = Snapshot.fixture(mine: [.fixture(number: 812, ci: .pending(done: 1, total: 3), reviewDecision: .approved)])
        let ready = Snapshot.fixture(mine: [.fixture(number: 812, ci: .success(total: 3), reviewDecision: .approved)], fetchedAt: t1)
        let events = TransitionEngine.events(from: old, to: ready).filter { $0.kind == .readyToMerge }
        #expect(events.count == 1)
        #expect(events.first?.title == "#812 pronto para merge")
        #expect(events.first?.body == "Aprovado, CI 3/3 e sem conflito")
        #expect(events.first?.url == URL(string: "https://github.com/acme/loja/pull/812"))
    }

    @Test func alreadyReadyDoesNotRenotify() {
        let old = Snapshot.fixture(mine: [.fixture(ci: .success(total: 3), reviewDecision: .approved)])
        let new = Snapshot.fixture(mine: [.fixture(ci: .success(total: 3), reviewDecision: .approved)], fetchedAt: t1)
        #expect(TransitionEngine.events(from: old, to: new).filter { $0.kind == .readyToMerge }.isEmpty)
    }

    @Test func readyBodyWithoutChecks() {
        let old = Snapshot.fixture(mine: [.fixture(ci: .none, reviewDecision: .reviewRequired)])
        let new = Snapshot.fixture(mine: [.fixture(ci: .none, reviewDecision: .approved)], fetchedAt: t1)
        let events = TransitionEngine.events(from: old, to: new).filter { $0.kind == .readyToMerge }
        #expect(events.first?.body == "Aprovado e sem conflito")
    }

    @Test func readyWithoutBranchProtectionNotifies() {
        let approval = Review(id: "r1", author: "ana", state: .approved, submittedAt: t0)
        let old = Snapshot.fixture(mine: [.fixture(reviews: [], reviewDecision: nil)])
        let new = Snapshot.fixture(mine: [.fixture(reviews: [approval], reviewDecision: nil)], fetchedAt: t1)
        #expect(TransitionEngine.events(from: old, to: new).filter { $0.kind == .readyToMerge }.count == 1)
    }

    @Test func conflictAndReadyComeAfterCommentEvents() {
        let old = Snapshot.fixture(mine: [.fixture(mergeable: .mergeable)])
        let new = Snapshot.fixture(
            mine: [.fixture(comments: [comment("c1")], mergeable: .conflicting)], fetchedAt: t1
        )
        #expect(TransitionEngine.events(from: old, to: new).map(\.kind) == [.newComment, .conflict])
    }

    @Test func unknownKeepsPreviousKnownMergeable() {
        let old = Snapshot.fixture(
            mine: [.fixture(id: "A", mergeable: .conflicting), .fixture(id: "B", mergeable: .mergeable)],
            toReview: [.fixture(id: "C", mergeable: .conflicting)]
        )
        let new = Snapshot.fixture(
            mine: [.fixture(id: "A", mergeable: .unknown), .fixture(id: "B", mergeable: .unknown), .fixture(id: "N", mergeable: .unknown)],
            toReview: [.fixture(id: "C", mergeable: .unknown)],
            fetchedAt: t1
        )
        let merged = new.keepingKnownMergeable(from: old)
        #expect(merged.mine.map(\.mergeable) == [.conflicting, .mergeable, .unknown])
        #expect(merged.toReview.map(\.mergeable) == [.conflicting])
        #expect(new.keepingKnownMergeable(from: nil) == new)
    }
}
