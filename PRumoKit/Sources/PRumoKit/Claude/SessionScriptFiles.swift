import Foundation

public enum SessionScriptFiles {
    static let maxAge: TimeInterval = 86_400

    public static func defaultSessionsDirectory(home: URL) -> URL {
        home.appendingPathComponent("Library/Caches/PRumo/sessions", isDirectory: true)
    }

    public static func write(_ contents: String, to url: URL) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try Data(contents.utf8).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
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
