import Foundation

public protocol FileSystem: Sendable {
    func directories(in url: URL) -> [URL]
    func exists(_ url: URL) -> Bool
}

public struct LocalFileSystem: FileSystem {
    public init() {}

    public func directories(in url: URL) -> [URL] {
        let children = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )) ?? []
        return children.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
    }

    public func exists(_ url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
}
