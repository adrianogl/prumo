public enum GitLabID {
    private static let prefix = "gitlab"
    private static let separator: Character = ":"

    public static func make(host: String, projectID: Int, iid: Int) -> String {
        [prefix, host.lowercased(), String(projectID), String(iid)].joined(separator: String(separator))
    }

    public static func parse(_ id: String) -> (host: String, projectID: Int, iid: Int)? {
        let parts = id.split(separator: separator, omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 4, parts[0] == prefix, !parts[1].isEmpty,
              let projectID = Int(parts[2]), let iid = Int(parts[3]) else { return nil }
        return (parts[1], projectID, iid)
    }
}
