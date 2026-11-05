import Foundation

enum ReviewRequestNote {
    private static let requestedReviewText = "requested review from"
    private static let approvedText = "approved this merge request"
    private static let unapprovedText = "unapproved this merge request"
    private static let changesRequestedText = "requested changes"

    static func requestedAt(notes: [GitLabNote], username: String) -> Date? {
        let mention = "@" + username.lowercased()
        return notes
            .filter { $0.system && containsMention(body: $0.body.lowercased(), mention: mention) }
            .map(\.createdAt)
            .max()
    }

    static func approvedAt(notes: [GitLabNote], username: String) -> Date? {
        guard let approved = latest(notes: notes, username: username, prefix: approvedText) else { return nil }
        if let unapproved = latest(notes: notes, username: username, prefix: unapprovedText), unapproved > approved {
            return nil
        }
        return approved
    }

    static func changesRequestedAt(notes: [GitLabNote], username: String) -> Date? {
        latest(notes: notes, username: username, prefix: changesRequestedText)
    }

    private static func latest(notes: [GitLabNote], username: String, prefix: String) -> Date? {
        notes
            .filter {
                $0.system
                    && $0.author?.username.lowercased() == username.lowercased()
                    && $0.body.lowercased().hasPrefix(prefix)
            }
            .map(\.createdAt)
            .max()
    }

    private static func containsMention(body: String, mention: String) -> Bool {
        guard let request = body.range(of: requestedReviewText) else { return false }
        var searchStart = request.upperBound
        while let range = body.range(of: mention, range: searchStart..<body.endIndex) {
            if range.upperBound == body.endIndex || !isUsernameCharacter(body[range.upperBound]) {
                return true
            }
            searchStart = range.upperBound
        }
        return false
    }

    private static func isUsernameCharacter(_ character: Character) -> Bool {
        character.isLetter || character.isNumber || character == "." || character == "_" || character == "-"
    }
}
