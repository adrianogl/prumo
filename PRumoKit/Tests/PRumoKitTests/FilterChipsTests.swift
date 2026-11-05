import Testing
@testable import PRumoKit

@Suite struct FilterChipsTests {
    @Test func chipsLabelsAndRemoval() {
        let filter = RowFilter(ci: [.failing], state: [.noDrafts])
        let chips = FilterChips.chips(filter, staleHours: 24)
        #expect(chips.map(\.label) == ["CI falhando", "Sem drafts"])
        let removed = filter.removing(.ci(.failing))
        #expect(removed == RowFilter(state: [.noDrafts]))
    }

    @Test func allLabels() {
        let filter = RowFilter(
            ci: [.passed, .running, .failing],
            review: [.approved, .changesRequested, .noReview],
            state: [.noDrafts, .conflicting, .newActivity, .pinned],
            request: [.forYou, .forTeam, .stale],
            authors: ["ana"]
        )
        #expect(FilterChips.chips(filter, staleHours: 48).map(\.label) == [
            "CI passou", "CI rodando", "CI falhando",
            "Aprovado", "Alterações pedidas", "Sem review",
            "Sem drafts", "Com conflito", "Com atividade nova", "Fixados",
            "Para você", "Para o time", "Parado há +48h",
            "Autor: ana"
        ])
        #expect(filter.removing(.author("ana")).authors.isEmpty)
    }
}
