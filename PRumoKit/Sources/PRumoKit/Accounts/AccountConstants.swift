public enum AccountConstants {
    public static let githubHost = "github.com"
    static let gitlabHost = "gitlab.com"
    static let publicHosts: Set<String> = [githubHost, gitlabHost]
    static let legacyKeychainAccount = "github-token"
    static let keychainPrefix = "token-"
    static let snapshotsFolder = "snapshots"
}
