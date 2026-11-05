import PRumoKit

extension PullRequest {
    var hasFailedCI: Bool {
        if case .failure = ci { return true }
        return false
    }
}
