import Foundation

public struct WorktreeRecord: Codable, Equatable, Sendable {
    public let pullRequestID: String
    public let number: Int
    public let path: String
    public let clone: String

    public init(pullRequestID: String, number: Int, path: String, clone: String) {
        self.pullRequestID = pullRequestID
        self.number = number
        self.path = path
        self.clone = clone
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pullRequestID = try container.decode(String.self, forKey: .pullRequestID)
        number = try container.decodeIfPresent(Int.self, forKey: .number) ?? 0
        path = try container.decode(String.self, forKey: .path)
        clone = try container.decode(String.self, forKey: .clone)
    }

    public static func registrable(
        pr: PullRequest, directory: URL, clone: URL, worktreesRoot: URL
    ) -> WorktreeRecord? {
        let rootPath = worktreesRoot.standardizedFileURL.path
        let path = directory.standardizedFileURL.path
        guard path.hasPrefix(rootPath + "/") else { return nil }
        return WorktreeRecord(pullRequestID: pr.id, number: pr.number, path: path, clone: clone.standardizedFileURL.path)
    }
}

public enum WorktreeCleanup {
    public static func stale(records: [WorktreeRecord], snapshot: Snapshot) -> [WorktreeRecord] {
        let open = Set((snapshot.mine + snapshot.toReview).map(\.id))
        return records.filter { !open.contains($0.pullRequestID) }
    }
}

public actor WorktreeRegistry {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func defaultURL() -> URL {
        URL.applicationSupportDirectory
            .appending(path: "PRumo", directoryHint: .isDirectory)
            .appending(path: "worktrees.json", directoryHint: .notDirectory)
    }

    public func add(_ record: WorktreeRecord) {
        var current = load()
        guard !current.contains(where: { $0.path == record.path }) else { return }
        current.append(record)
        save(current)
    }

    public func records() -> [WorktreeRecord] {
        load()
    }

    public func remove(path: String) {
        let current = load()
        let remaining = current.filter { $0.path != path }
        guard remaining.count != current.count else { return }
        save(remaining)
    }

    private func load() -> [WorktreeRecord] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([WorktreeRecord].self, from: data)) ?? []
    }

    private func save(_ records: [WorktreeRecord]) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(records) else { return }
        try? FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
