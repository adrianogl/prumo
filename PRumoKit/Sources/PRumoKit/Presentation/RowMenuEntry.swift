import Foundation

public enum RowMenuEntry: Equatable, Sendable {
    case claude(SessionPurpose, primary: Bool)
    case openInBrowser
    case openJira(key: String, url: URL)
    case rerunFailedJobs(jobName: String, runID: Int, disabledReason: String?)
    case copyLink
    case copyCheckout(command: String, warning: String?)
    case separator
    case pin(isPinned: Bool)
    case mute(isMuted: Bool)
}
