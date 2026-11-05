public enum ClaudeLaunchError: Error, Equatable {
    case cloneNotFound(repository: String)
    case worktree(String)
    case launchFailed(String)
}
