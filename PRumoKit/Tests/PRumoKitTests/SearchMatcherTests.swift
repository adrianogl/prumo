import Foundation
import Testing
@testable import PRumoKit

@Suite struct SearchMatcherTests {
    let pr = PullRequest.fixture(id: "PR_812", number: 812, title: "Corrige cálculo do carrinho", repository: "acme/web-app")

    @Test func matchesTitleIgnoringCaseAndAccents() {
        #expect(SearchMatcher.matches(pr, query: "calculo"))
        #expect(SearchMatcher.matches(pr, query: "CÁLCULO"))
        #expect(!SearchMatcher.matches(pr, query: "frete"))
    }

    @Test func matchesRepository() {
        #expect(SearchMatcher.matches(pr, query: "web-app"))
    }

    @Test func matchesNumberWithHash() {
        #expect(SearchMatcher.matches(pr, query: "#81"))
        #expect(SearchMatcher.matches(pr, query: "812"))
        #expect(!SearchMatcher.matches(pr, query: "#12"))
    }

    @Test func allTermsMustMatch() {
        #expect(SearchMatcher.matches(pr, query: "calculo web-app"))
        #expect(!SearchMatcher.matches(pr, query: "calculo api"))
    }

    @Test func emptyQueryMatchesAll() {
        #expect(SearchMatcher.matches(pr, query: ""))
        #expect(SearchMatcher.matches(pr, query: "   "))
        #expect(SearchMatcher.matches(pr, query: "#"))
    }

    @Test func matchesMergedPullRequest() {
        let merged = MergedPullRequest(
            id: "M", number: 812, title: "Corrige cálculo", url: URL(string: "https://github.com/acme/loja/pull/812")!,
            repository: "acme/web-app", mergedAt: .fixed
        )
        #expect(SearchMatcher.matches(merged, query: "calculo"))
        #expect(SearchMatcher.matches(merged, query: "#81"))
        #expect(!SearchMatcher.matches(merged, query: "frete"))
    }
}
