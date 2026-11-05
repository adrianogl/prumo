import Foundation

public actor ReminderStore {
    private let fileURL: URL

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func defaultURL() -> URL {
        URL.applicationSupportDirectory
            .appending(path: "PRumo", directoryHint: .isDirectory)
            .appending(path: "reminders.json", directoryHint: .notDirectory)
    }

    public func load() -> ReminderState {
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? JSONDecoder().decode(ReminderState.self, from: data)
        else { return ReminderState() }
        return state
    }

    public func save(_ state: ReminderState) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(state)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }
}
