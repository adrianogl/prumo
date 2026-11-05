import Foundation
import Testing
@testable import PRumoKit

@testable import struct PRumoKit.Comment
private typealias PRComment = Comment

private func comment(_ id: String, author: String, bot: Bool = false) -> PRComment {
    PRComment(id: id, author: author, authorIsBot: bot, body: "ok", url: URL(string: "https://github.com/acme/loja/pull/812#\(id)")!, createdAt: .fixed)
}

@Suite struct CommentAuthorFilterTests {
    @Test func botIsAlwaysIgnored() {
        #expect(CommentAuthorFilter.none.isIgnored(author: "dependabot", isBot: true))
        #expect(CommentAuthorFilter.none.isIgnored(author: "ana", isBot: false) == false)
    }

    @Test func listedAuthorIgnoresCaseAndBotSuffix() {
        let filter = CommentAuthorFilter(ignoredAuthors: [" GitHub-Actions ", "datadog-official[bot]"])
        #expect(filter.isIgnored(author: "github-actions", isBot: false))
        #expect(filter.isIgnored(author: "github-actions[bot]", isBot: false))
        #expect(filter.isIgnored(author: "Datadog-Official", isBot: false))
        #expect(filter.isIgnored(author: "ana", isBot: false) == false)
    }

    @Test func blankEntriesAreDropped() {
        let filter = CommentAuthorFilter(ignoredAuthors: ["", "  ", "[bot]"])
        #expect(filter.ignoredAuthors.isEmpty)
        #expect(filter.isIgnored(author: "", isBot: false) == false)
    }

    @Test func commentTotalSubtractsIgnoredFetchedComments() {
        let pr = PullRequest.fixture(
            comments: [
                comment("c1", author: "github-actions"),
                comment("c2", author: "ana"),
                comment("c3", author: "renovate", bot: true)
            ],
            commentCount: 3
        )
        let filter = CommentAuthorFilter(ignoredAuthors: ["github-actions"])
        #expect(filter.commentTotal(pr) == 1)
    }

    @Test func commentTotalIsApproximateBeyondFetchedWindow() {
        let pr = PullRequest.fixture(comments: [comment("c1", author: "github-actions")], commentCount: 25)
        #expect(CommentAuthorFilter(ignoredAuthors: ["github-actions"]).commentTotal(pr) == 24)
    }

    @Test func commentTotalIsNeverNegative() {
        let pr = PullRequest.fixture(
            comments: [comment("c1", author: "github-actions"), comment("c2", author: "github-actions")],
            commentCount: 1
        )
        #expect(CommentAuthorFilter(ignoredAuthors: ["github-actions"]).commentTotal(pr) == 0)
    }

    @Test func commentTotalSkipsIgnoredCommentedReviews() {
        let pr = PullRequest.fixture(reviews: [
            Review(id: "r1", author: "ana", state: .commented, submittedAt: .fixed, body: "Veja"),
            Review(id: "r2", author: "Datadog-Official[bot]", state: .commented, submittedAt: .fixed, body: "Relatório"),
            Review(id: "r3", author: "copilot", authorIsBot: true, state: .commented, submittedAt: .fixed, body: "Sugestão")
        ])
        #expect(CommentAuthorFilter(ignoredAuthors: ["datadog-official"]).commentTotal(pr) == 1)
    }
}
