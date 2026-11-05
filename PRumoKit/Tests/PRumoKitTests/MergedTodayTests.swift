import Foundation
import Testing
@testable import PRumoKit

struct MergedTodayTests {
    private func merged(_ id: String, at iso: String) -> MergedPullRequest {
        MergedPullRequest(
            id: id, number: 1, title: id, url: URL(string: "https://github.com/acme/loja/pull/1")!,
            repository: "acme/loja", mergedAt: ISO8601DateFormatter().date(from: iso)!
        )
    }

    @Test func mergedTodayDropsYesterdayAndSortsNewestFirst() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Sao_Paulo")!
        let now = ISO8601DateFormatter().date(from: "2026-11-05T17:00:00Z")!
        let list = [
            merged("manha", at: "2026-11-05T12:00:00Z"),
            merged("ontem", at: "2026-11-05T02:59:00Z"),
            merged("tarde", at: "2026-11-05T16:00:00Z"),
            merged("meia-noite", at: "2026-11-05T03:00:00Z"),
        ]
        #expect(MergedToday.items(list, now: now, calendar: calendar).map(\.id) == ["tarde", "manha", "meia-noite"])
    }
}
