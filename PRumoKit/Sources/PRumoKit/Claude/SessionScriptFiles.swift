import Foundation

public enum SessionScriptFiles {
    static let maxAge: TimeInterval = 86_400

    public static func defaultSessionsDirectory(home: URL) -> URL {
        home.appendingPathComponent("Library/Caches/PRumo/sessions", isDirectory: true)
    }

    public static func write(_ contents: String, to url: URL) throws {
        let manager = FileManager.default
        let directory = url.deletingLastPathComponent()
        try manager.createDirectory(
            at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let temporary = directory.appendingPathComponent(".\(UUID().uuidString).tmp")
        guard manager.createFile(
            atPath: temporary.path, contents: Data(contents.utf8), attributes: [.posixPermissions: 0o700])
        else {
            throw CocoaError(.fileWriteUnknown)
        }
        do {
            if manager.fileExists(atPath: url.path) { try manager.removeItem(at: url) }
            try manager.moveItem(at: temporary, to: url)
        } catch {
            try? manager.removeItem(at: temporary)
            throw error
        }
    }

    public static func cleanup(in directory: URL, now: Date) {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: [])) ?? []
        for file in files where file.pathExtension == "zsh" {
            guard let modified = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                now.timeIntervalSince(modified) > maxAge
            else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }
}
