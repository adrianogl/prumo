import Foundation

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
