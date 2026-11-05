import Foundation

public enum RowMenuPlan {
    public static func entries(
        pr: PullRequest, claudePurposes: [SessionPurpose],
        jira: JiraLink?,
        isPinned: Bool = false,
        isMuted: Bool = false
    ) -> [RowMenuEntry] {
        var entries: [RowMenuEntry] = []
        for (index, purpose) in claudePurposes.enumerated() {
            entries.append(.claude(purpose, primary: index == 0))
        }
        if !claudePurposes.isEmpty { entries.append(.separator) }
        entries.append(.openInBrowser)
        if let jira, let url = jira.url { entries.append(.openJira(key: jira.key, url: url)) }
        if let runID = pr.failedRunID, case .failure = pr.ci {
            entries.append(.rerunFailedJobs(jobName: pr.failedRunName ?? "", runID: runID))
        }
        entries.append(.copyLink)
        entries.append(.copyCheckout(command: "gh pr checkout \(pr.number)"))
        entries.append(.separator)
        entries.append(.pin(isPinned: isPinned))
        entries.append(.mute(isMuted: isMuted))
        return entries
    }
}
