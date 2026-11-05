import Foundation

public struct CommentAuthorFilter: Equatable, Sendable {
    public let ignoredAuthors: Set<String>

    public static let none = CommentAuthorFilter(ignoredAuthors: [])

    public init<Authors: Sequence>(ignoredAuthors: Authors) where Authors.Element == String {
        self.ignoredAuthors = Set(ignoredAuthors.map(Self.normalized).filter { !$0.isEmpty })
    }

    public static func normalized(_ login: String) -> String {
        let lowered = login.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard lowered.hasSuffix(OrganizationConstants.botSuffix) else { return lowered }
        return String(lowered.dropLast(OrganizationConstants.botSuffix.count))
    }

    public func isIgnored(author: String, isBot: Bool) -> Bool {
        isBot || ignoredAuthors.contains(Self.normalized(author))
    }

    public func isIgnored(_ comment: Comment) -> Bool {
        isIgnored(author: comment.author, isBot: comment.authorIsBot)
    }

    public func isIgnored(_ review: Review) -> Bool {
        isIgnored(author: review.author, isBot: review.authorIsBot)
    }

    public func commentTotal(_ pr: PullRequest) -> Int {
        let ignoredFetched = pr.comments.filter { isIgnored($0) }.count
        let issueComments = max(0, pr.commentCount - ignoredFetched)
        let reviewComments = pr.reviews.filter { $0.isComment && !isIgnored($0) }.count
        return issueComments + reviewComments
    }
}
