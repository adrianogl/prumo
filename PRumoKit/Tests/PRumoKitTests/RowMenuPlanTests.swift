import Foundation
import Testing
@testable import PRumoKit

@Suite struct RowMenuPlanTests {
    private let jiraURL = URL(string: "https://acme.atlassian.net/browse/ON-1234")!
    private let failing = CIStatus.failure(failedChecks: ["unit-tests"], total: 9)

    @Test func menuOrderWithEverything() {
        let pr = PullRequest.fixture(ci: failing, failedRunID: 555, failedRunName: "unit-tests")
        let entries = RowMenuPlan.entries(
            pr: pr, claudePurposes: [.fixCI, .addressComments], jira: JiraLink(key: "ON-1234", url: jiraURL)
        )
        #expect(entries == [
            .claude(.fixCI, primary: true),
            .claude(.addressComments, primary: false),
            .separator,
            .openInBrowser,
            .openJira(key: "ON-1234", url: jiraURL),
            .rerunFailedJobs(jobName: "unit-tests", runID: 555, disabledReason: nil),
            .copyLink,
            .copyCheckout(command: "gh pr checkout 812", warning: nil),
            .separator,
            .pin(isPinned: false),
            .mute(isMuted: false),
        ])
    }

    @Test func gitlabCheckoutCommand() {
        let entries = RowMenuPlan.entries(pr: .fixture(number: 341, provider: .gitlab), claudePurposes: [], jira: nil)
        #expect(entries.contains(.copyCheckout(command: "glab mr checkout 341", warning: nil)))
    }

    @Test func githubCheckoutUnchanged() {
        let entries = RowMenuPlan.entries(pr: .fixture(provider: .github), claudePurposes: [], jira: nil)
        #expect(entries.contains(.copyCheckout(command: "gh pr checkout 812", warning: nil)))
    }

    @Test func pinAndMuteEntriesComeLast() {
        let entries = RowMenuPlan.entries(pr: .fixture(), claudePurposes: [], jira: nil)
        #expect(entries.suffix(4) == [
            .copyCheckout(command: "gh pr checkout 812", warning: nil),
            .separator,
            .pin(isPinned: false),
            .mute(isMuted: false),
        ])
    }

    @Test func entriesReflectPinnedAndMuted() {
        let entries = RowMenuPlan.entries(
            pr: .fixture(), claudePurposes: [], jira: nil, isPinned: true, isMuted: true)
        #expect(entries.suffix(2) == [.pin(isPinned: true), .mute(isMuted: true)])
    }

    @Test func noClaudeNoSeparator() {
        let entries = RowMenuPlan.entries(pr: .fixture(), claudePurposes: [], jira: nil)
        #expect(entries.first == .openInBrowser)
        #expect(entries.filter { $0 == .separator }.count == 1)
    }

    @Test func noJiraEntryWithoutURL() {
        let entries = RowMenuPlan.entries(pr: .fixture(), claudePurposes: [], jira: JiraLink(key: "DEV-7", url: nil))
        #expect(!entries.contains { if case .openJira = $0 { true } else { false } })
    }

    @Test func noRerunWithoutRunID() {
        let entries = RowMenuPlan.entries(pr: .fixture(ci: failing), claudePurposes: [], jira: nil)
        #expect(!entries.contains { if case .rerunFailedJobs = $0 { true } else { false } })
    }

    @Test func noRerunWhenCINotFailing() {
        let pr = PullRequest.fixture(ci: .success(total: 9), failedRunID: 555, failedRunName: "unit-tests")
        let entries = RowMenuPlan.entries(pr: pr, claudePurposes: [], jira: nil)
        #expect(!entries.contains { if case .rerunFailedJobs = $0 { true } else { false } })
    }

    @Test func planCarriesWarning() {
        let entries = RowMenuPlan.entries(pr: .fixture(), claudePurposes: [], jira: nil, checkoutWarning: "aviso")
        #expect(entries.contains(.copyCheckout(command: "gh pr checkout 812", warning: "aviso")))
    }

    @Test func planCarriesDisabledReason() {
        let pr = PullRequest.fixture(ci: failing, failedRunID: 555, failedRunName: "unit-tests")
        let entries = RowMenuPlan.entries(pr: pr, claudePurposes: [], jira: nil, rerunDisabledReason: "sem escopo")
        #expect(entries.contains(.rerunFailedJobs(jobName: "unit-tests", runID: 555, disabledReason: "sem escopo")))
    }

    @Test func gitlabPipelineWithoutNameFallsBackToPipeline() {
        let pr = PullRequest.fixture(ci: failing, failedRunID: 9, provider: .gitlab)
        let entries = RowMenuPlan.entries(pr: pr, claudePurposes: [], jira: nil)
        #expect(entries.contains(.rerunFailedJobs(jobName: "pipeline", runID: 9, disabledReason: nil)))
    }

    private var stuck: PullRequest {
        PullRequest.fixture(ci: .pending(done: 0, total: 3), ciPendingSince: Date.fixed.addingTimeInterval(-3600), pendingRunIDs: [77])
    }

    @Test func planShowsCancelAndRerunWhenStuck() {
        let entries = RowMenuPlan.entries(pr: stuck, claudePurposes: [], jira: nil, isCIStuck: true)
        let index = entries.firstIndex(of: .cancelAndRerun(disabledReason: nil))
        #expect(index != nil)
        #expect(index.map { entries[$0 + 1] } == .copyLink)
    }

    @Test func planHidesCancelAndRerunWhenNotStuck() {
        let entries = RowMenuPlan.entries(pr: stuck, claudePurposes: [], jira: nil)
        #expect(!entries.contains { if case .cancelAndRerun = $0 { true } else { false } })
    }

    @Test func planHidesWhenNoCancelableRun() {
        let pr = PullRequest.fixture(ci: .pending(done: 0, total: 3), ciPendingSince: Date.fixed.addingTimeInterval(-3600))
        let entries = RowMenuPlan.entries(pr: pr, claudePurposes: [], jira: nil, isCIStuck: true)
        #expect(!entries.contains { if case .cancelAndRerun = $0 { true } else { false } })
    }

    @Test func gitlabStuckDisabledWithoutApiScope() {
        let pr = PullRequest.fixture(
            ci: .pending(done: 0, total: 3), provider: .gitlab,
            ciPendingSince: Date.fixed.addingTimeInterval(-3600), pendingRunIDs: [5003])
        let reason = RerunAvailability.disabledReason(provider: .gitlab, scopes: ["read_api"])
        let entries = RowMenuPlan.entries(pr: pr, claudePurposes: [], jira: nil, rerunDisabledReason: reason, isCIStuck: true)
        #expect(reason != nil)
        #expect(entries.contains(.cancelAndRerun(disabledReason: reason)))
    }
}
