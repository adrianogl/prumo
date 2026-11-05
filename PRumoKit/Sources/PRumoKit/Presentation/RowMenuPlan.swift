import Foundation

public enum RowMenuPlan {
    private static let pipelineLabel = "pipeline"

    public static func entries(
        pr: PullRequest, claudePurposes: [SessionPurpose],
        jira: JiraLink?,
        isPinned: Bool = false,
        isMuted: Bool = false,
        checkoutWarning: String? = nil,
        rerunDisabledReason: String? = nil
    ) -> [RowMenuEntry] {
        var entries: [RowMenuEntry] = []
        for (index, purpose) in claudePurposes.enumerated() {
            entries.append(.claude(purpose, primary: index == 0))
        }
        if !claudePurposes.isEmpty { entries.append(.separator) }
        entries.append(.openInBrowser)
        if let jira, let url = jira.url { entries.append(.openJira(key: jira.key, url: url)) }
        if let runID = pr.failedRunID, case .failure = pr.ci {
            entries.append(.rerunFailedJobs(jobName: pr.failedRunName ?? (pr.provider == .gitlab ? Self.pipelineLabel : ""), runID: runID, disabledReason: rerunDisabledReason))
        }
        entries.append(.copyLink)
        entries.append(.copyCheckout(command: checkoutCommand(for: pr), warning: checkoutWarning))
        entries.append(.separator)
        entries.append(.pin(isPinned: isPinned))
        entries.append(.mute(isMuted: isMuted))
        return entries
    }

    private static func checkoutCommand(for pr: PullRequest) -> String {
        switch pr.provider {
        case .github: "gh pr checkout \(pr.number)"
        case .gitlab: "glab mr checkout \(pr.number)"
        }
    }
}
