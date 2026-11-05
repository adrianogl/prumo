import Foundation

public struct CloneLocator: Sendable {
    static let maxDepth = 3
    static let excludedNames: Set<String> = ["node_modules", ".build", "DerivedData", "vendor"]

    private let root: URL
    private let fileSystem: FileSystem
    private let runner: ProcessRunner
    private let gitlabHosts: Set<String>

    public init(root: URL, fileSystem: FileSystem, runner: ProcessRunner, gitlabHosts: Set<String> = []) {
        self.root = root
        self.fileSystem = fileSystem
        self.runner = runner
        self.gitlabHosts = gitlabHosts
    }

    public func scan() async -> [String: [URL]] {
        var found: [String: [URL]] = [:]
        for directory in repositoryDirectories(in: root, depth: 1) {
            guard let result = try? await runner.run(
                "/usr/bin/git",
                ["-C", directory.path, "remote", "get-url", "origin"]
            ), result.status == 0,
                let repository = RemoteURL.repositoryKey(from: result.stdout, gitlabHosts: gitlabHosts)
            else { continue }
            found[repository, default: []].append(directory)
        }
        return found.mapValues { $0.sorted { $0.path < $1.path } }
    }

    private func repositoryDirectories(in directory: URL, depth: Int) -> [URL] {
        guard depth <= Self.maxDepth else { return [] }
        var result: [URL] = []
        for child in fileSystem.directories(in: directory).sorted(by: { $0.path < $1.path }) {
            let name = child.lastPathComponent
            if name.hasPrefix(".") || Self.excludedNames.contains(name) { continue }
            if fileSystem.exists(child.appendingPathComponent(".git")) {
                result.append(child)
            } else {
                result += repositoryDirectories(in: child, depth: depth + 1)
            }
        }
        return result
    }
}
