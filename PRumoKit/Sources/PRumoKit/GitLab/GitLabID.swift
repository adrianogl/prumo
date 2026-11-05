public enum GitLabID {
    private static let prefix = "gitlab"
    private static let separator: Character = ":"

    public static func make(host: String, projectID: Int, iid: Int) -> String {
        [prefix, host.lowercased(), String(projectID), String(iid)].joined(separator: String(separator))
    }

    public static func parse(_ id: String) -> (host: String, projectID: Int, iid: Int)? {
        let parts = id.split(separator: separator, omittingEmptySubsequences: false).map(String.init)
        guard parts.count >= 4, parts[0] == prefix,
              let projectID = Int(parts[parts.count - 2]), let iid = Int(parts[parts.count - 1]) else { return nil }
        let host = parts[1..<(parts.count - 2)].joined(separator: String(separator))
        guard !host.isEmpty else { return nil }
        return (host, projectID, iid)
    }
}
