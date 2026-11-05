import Foundation

public enum SearchMatcher {
    public static func matches(_ pr: PullRequest, query: String) -> Bool {
        matches(title: pr.title, repository: pr.repository, number: pr.number, query: query)
    }

    public static func matches(_ merged: MergedPullRequest, query: String) -> Bool {
        matches(title: merged.title, repository: merged.repository, number: merged.number, query: query)
    }

    private static func matches(title: String, repository: String, number: Int, query: String) -> Bool {
        let terms = terms(from: query)
        guard !terms.isEmpty else { return true }
        let title = normalized(title)
        let repository = normalized(repository)
        let number = String(number)
        return terms.allSatisfy { term in
            title.contains(term)
                || repository.contains(term)
                || (term.allSatisfy(\.isASCII) && term.allSatisfy(\.isNumber) && number.hasPrefix(term))
        }
    }

    private static func terms(from query: String) -> [String] {
        normalized(query)
            .split(whereSeparator: \.isWhitespace)
            .map { String($0.drop(while: { $0 == "#" })) }
            .filter { !$0.isEmpty }
    }

    private static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
