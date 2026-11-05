import Foundation
import Testing
@testable import PRumoKit

@Suite struct StuckCITests {
    private let threshold: TimeInterval = 30 * 60
    private let pending = CIStatus.pending(done: 1, total: 3)

    @Test func stuckAfterThreshold() {
        let pr = PullRequest.fixture(ci: pending, ciPendingSince: Date.fixed.addingTimeInterval(-3 * 3600), pendingRunIDs: [7])
        #expect(StuckCI.since(pr: pr, now: .fixed, threshold: threshold).map { Int($0.rounded()) } == 3 * 3600)
        #expect(StuckCI.isCancelable(pr: pr, now: .fixed, threshold: threshold))
    }

    @Test func notStuckBeforeThreshold() {
        let pr = PullRequest.fixture(ci: pending, ciPendingSince: Date.fixed.addingTimeInterval(-29 * 60), pendingRunIDs: [7])
        #expect(StuckCI.since(pr: pr, now: .fixed, threshold: threshold) == nil)
        #expect(!StuckCI.isCancelable(pr: pr, now: .fixed, threshold: threshold))
    }

    @Test func notStuckWhenCIFinished() {
        let since = Date.fixed.addingTimeInterval(-3 * 3600)
        for ci in [CIStatus.success(total: 3), .failure(failedChecks: ["lint"], total: 3), .none] {
            let pr = PullRequest.fixture(ci: ci, ciPendingSince: since, pendingRunIDs: [7])
            #expect(StuckCI.since(pr: pr, now: .fixed, threshold: threshold) == nil)
        }
    }

    @Test func notStuckWithoutStartDate() {
        let pr = PullRequest.fixture(ci: pending, pendingRunIDs: [7])
        #expect(StuckCI.since(pr: pr, now: .fixed, threshold: threshold) == nil)
    }

    @Test func notCancelableWithoutRun() {
        let pr = PullRequest.fixture(ci: pending, ciPendingSince: Date.fixed.addingTimeInterval(-3 * 3600))
        #expect(StuckCI.since(pr: pr, now: .fixed, threshold: threshold) != nil)
        #expect(!StuckCI.isCancelable(pr: pr, now: .fixed, threshold: threshold))
    }

    @Test func stuckDurationText() {
        #expect(StuckCI.text(40 * 60) == "CI parado há 40 min")
        #expect(StuckCI.text(3 * 3600 + 25 * 60) == "CI parado há 3 h")
        #expect(StuckCI.text(60 * 60) == "CI parado há 1 h")
    }

    @Test func subtitleShowsStuckText() {
        let pr = PullRequest.fixture(ci: pending)
        let row = RowPresenter.mine(pr, viewer: "adriano", now: .fixed, ciStuckFor: 40 * 60)
        #expect(row.subtitle.hasSuffix(" · CI parado há 40 min"))
        let plain = RowPresenter.mine(pr, viewer: "adriano", now: .fixed)
        #expect(!plain.subtitle.contains("CI parado"))
    }

    @Test func compactLineReplacesRunningWithStuckText() {
        let pr = PullRequest.fixture(ci: pending)
        let line = RowPresenter.compactLine(pr, tab: .mine, viewer: "adriano", now: .fixed, ciStuckFor: 3 * 3600)
        #expect(line.contains("CI parado há 3 h"))
        #expect(!line.contains("CI rodando"))
    }

    @Test func oldPullRequestJSONWithoutStuckFieldsDecodes() throws {
        let data = try JSONEncoder().encode(PullRequest.fixture(ciPendingSince: .fixed, pendingRunIDs: [1, 2]))
        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        object.removeValue(forKey: "ciPendingSince")
        object.removeValue(forKey: "pendingRunIDs")
        let pr = try JSONDecoder().decode(PullRequest.self, from: JSONSerialization.data(withJSONObject: object))
        #expect(pr.ciPendingSince == nil)
        #expect(pr.pendingRunIDs == [])
    }

    @Test func stuckFieldsRoundTrip() throws {
        let original = PullRequest.fixture(ciPendingSince: .fixed, pendingRunIDs: [1, 2])
        let decoded = try JSONDecoder().decode(PullRequest.self, from: JSONEncoder().encode(original))
        #expect(decoded == original)
    }

    @Test func thresholdDefaultsWhenMissingOrInvalid() throws {
        let empty = try JSONDecoder().decode(OrganizationSettings.self, from: Data("{}".utf8))
        #expect(empty.stuckCIThreshold == 30 * 60)
        let broken = try JSONDecoder().decode(OrganizationSettings.self, from: Data(#"{"stuckCIThreshold":"x"}"#.utf8))
        #expect(broken.stuckCIThreshold == 30 * 60)
        let saved = try JSONDecoder().decode(OrganizationSettings.self, from: Data(#"{"stuckCIThreshold":3600}"#.utf8))
        #expect(saved.stuckCIThreshold == 3600)
    }
}
