import Foundation

public enum TransitionEngine {
    public static func events(from old: Snapshot?, to new: Snapshot, options: TransitionOptions = .init()) -> [NotificationEvent] {
        guard let old, old.viewer == new.viewer else { return [] }
        let oldMine = Dictionary(old.mine.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var result: [NotificationEvent] = []
        let threshold = old.fetchedAt.addingTimeInterval(-TransitionConstants.dateTolerance)
        for pr in new.mine {
            guard let before = oldMine[pr.id] else { continue }
            result += ciEvents(before, pr)
            result += reviewEvents(before, pr, viewer: new.viewer, since: threshold)
            result += commentEvents(before, pr, viewer: new.viewer, since: threshold)
        }
        let oldToReviewIDs = Set(old.toReview.map(\.id))
        let knownReviewRequests = Set(directRequests(old.toReview, options).map(\.id))
        for pr in directRequests(new.toReview, options) where !knownReviewRequests.contains(pr.id) {
            if !oldToReviewIDs.contains(pr.id), let requestedAt = pr.reviewRequestedAt, requestedAt <= threshold { continue }
            result.append(NotificationEvent(
                kind: .reviewRequested, pullRequestID: pr.id,
                title: "Review pedido: #\(pr.number)",
                body: "\(pr.author) pediu seu review em \(pr.title)", url: pr.url
            ))
        }
        return result
    }

    private static func directRequests(_ prs: [PullRequest], _ options: TransitionOptions) -> [PullRequest] {
        ReviewInclusion.visible(prs, ignoreDrafts: options.ignoreDraftReviews, includeTeam: false)
    }

    private static func ciEvents(_ old: PullRequest, _ new: PullRequest) -> [NotificationEvent] {
        guard new.ci.isTerminal, !old.ci.isTerminal || old.headSHA != new.headSHA else { return [] }
        let checksURL = new.url.appendingPathComponent("checks")
        switch new.ci {
        case .success(let total):
            return [NotificationEvent(
                kind: .ciSucceeded, pullRequestID: new.id,
                title: "CI terminou em #\(new.number): \(total)/\(total)", body: new.title, url: checksURL
            )]
        case .failure(let failedChecks, _):
            let first = failedChecks.first.map { " · \($0)" } ?? ""
            return [NotificationEvent(
                kind: .ciFailed, pullRequestID: new.id,
                title: "CI falhou em #\(new.number)", body: "\(new.title)\(first)", url: checksURL,
                failedRunID: new.failedRunID
            )]
        case .none, .pending:
            return []
        }
    }

    private static func reviewEvents(_ old: PullRequest, _ new: PullRequest, viewer: String, since: Date) -> [NotificationEvent] {
        let known = Set(old.reviews.map(\.id))
        let events: [NotificationEvent] = new.reviews.compactMap { review in
            guard !known.contains(review.id), review.author != viewer, review.submittedAt > since else { return nil }
            switch review.state {
            case .approved:
                return NotificationEvent(
                    kind: .approved, pullRequestID: new.id, title: "#\(new.number) aprovado",
                    body: "\(review.author) aprovou \(new.title)", url: new.url
                )
            case .changesRequested:
                return NotificationEvent(
                    kind: .changesRequested, pullRequestID: new.id, title: "Alterações pedidas em #\(new.number)",
                    body: "\(review.author) pediu alterações em \(new.title)", url: new.url
                )
            case .commented, .dismissed, .pending:
                return nil
            }
        }
        return events.filter { $0.kind == .approved } + events.filter { $0.kind == .changesRequested }
    }

    private static func commentEvents(_ old: PullRequest, _ new: PullRequest, viewer: String, since: Date) -> [NotificationEvent] {
        let knownComments = Set(old.comments.map(\.id))
        let knownReviews = Set(old.reviews.map(\.id))
        let comments = new.comments
            .filter { !knownComments.contains($0.id) && $0.author != viewer && !$0.authorIsBot && $0.createdAt > since }
            .map { (author: $0.author, body: $0.body, url: $0.url, date: $0.createdAt) }
        let reviews = new.reviews
            .filter { !knownReviews.contains($0.id) && $0.isComment && $0.author != viewer && !$0.authorIsBot && $0.submittedAt > since }
            .map { (author: $0.author, body: $0.body, url: $0.url ?? new.url, date: $0.submittedAt) }
        let fresh = comments + reviews
        guard let latest = fresh.max(by: { $0.date < $1.date }) else { return [] }
        let title = fresh.count > 1 ? "\(fresh.count) comentários novos em #\(new.number)" : "Comentário novo em #\(new.number)"
        return [NotificationEvent(
            kind: .newComment, pullRequestID: new.id, title: title,
            body: "\(latest.author): \"\(excerpt(latest.body))\"", url: latest.url
        )]
    }

    private static func excerpt(_ text: String) -> String {
        let flat = text.replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        return flat.count > TransitionConstants.bodyLimit ? String(flat.prefix(TransitionConstants.bodyLimit)) + "…" : flat
    }
}
