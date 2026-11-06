import Foundation

public struct LocalUpdateFileManager: UpdateFileManaging {
    public init() {}

    public func isWritable(_ url: URL) -> Bool {
        FileManager.default.isWritableFile(atPath: url.path)
    }

    public func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    public func createDirectory(_ url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    public func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }

    public func copyItem(at source: URL, to destination: URL) throws {
        try FileManager.default.copyItem(at: source, to: destination)
    }

    public func replaceItem(at original: URL, with replacement: URL) throws {
        _ = try FileManager.default.replaceItemAt(original, withItemAt: replacement)
    }

    public func removeItem(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
