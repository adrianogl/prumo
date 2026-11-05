import Foundation

public enum RowMenuEntry: Equatable, Sendable {
    case claude(SessionPurpose, primary: Bool)
    case openInBrowser
    case openJira(key: String, url: URL)
    case rerunFailedJobs(jobName: String, runID: Int)
    case copyLink
    case copyCheckout(command: String)
    case separator
}
