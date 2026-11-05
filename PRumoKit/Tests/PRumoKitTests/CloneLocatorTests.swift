import Foundation
import Testing
@testable import PRumoKit

private struct FakeFileSystem: FileSystem {
    var tree: [String: [String]]
    var gitMarkers: Set<String>

    func directories(in url: URL) -> [URL] {
        (tree[url.path] ?? []).map { url.appendingPathComponent($0) }
    }

    func exists(_ url: URL) -> Bool {
        gitMarkers.contains(url.path)
    }
}

private struct RemoteRunner: ProcessRunner {
    var remotes: [String: String]

    func run(_ executable: String, _ args: [String]) async throws -> (status: Int32, stdout: String, stderr: String) {
        guard executable == "/usr/bin/git", args.count == 5, args[0] == "-C",
              args[2...] == ["remote", "get-url", "origin"],
              let remote = remotes[args[1]]
        else { return (1, "", "erro") }
        return (0, remote + "\n", "")
    }
}

@Suite struct CloneLocatorTests {
    let root = URL(fileURLWithPath: "/code")

    @Test func parsesSSHAndHTTPSRemotes() {
        #expect(RemoteURL.repository(from: "git@github.com:Org/Repo.git") == "org/repo")
        #expect(RemoteURL.repository(from: "https://github.com/Org/Repo.git") == "org/repo")
        #expect(RemoteURL.repository(from: "https://github.com/org/repo") == "org/repo")
        #expect(RemoteURL.repository(from: "ssh://git@github.com/org/repo.git") == "org/repo")
    }

    @Test func rejectsOtherHosts() {
        #expect(RemoteURL.repository(from: "git@gitlab.com:org/repo.git") == nil)
        #expect(RemoteURL.repository(from: "https://bitbucket.org/org/repo.git") == nil)
        #expect(RemoteURL.repository(from: "nonsense") == nil)
    }

    @Test func scanFindsReposUpToDepth3AndSkipsExcluded() async {
        let fs = FakeFileSystem(
            tree: [
                "/code": ["a", "node_modules", ".hidden", "b"],
                "/code/a": ["front"],
                "/code/b": ["deep"],
                "/code/b/deep": ["deeper"],
                "/code/b/deep/deeper": ["toolow"],
                "/code/node_modules": ["pkg"],
                "/code/.hidden": ["secret"],
                "/code/a/front": ["inner"]
            ],
            gitMarkers: [
                "/code/a/front/.git", "/code/b/deep/deeper/.git",
                "/code/b/deep/deeper/toolow/.git", "/code/node_modules/pkg/.git",
                "/code/.hidden/secret/.git", "/code/a/front/inner/.git"
            ]
        )
        let runner = RemoteRunner(remotes: [
            "/code/a/front": "git@github.com:org/front.git",
            "/code/b/deep/deeper": "https://github.com/org/deeper.git",
            "/code/b/deep/deeper/toolow": "https://github.com/org/toolow.git",
            "/code/node_modules/pkg": "https://github.com/org/pkg.git",
            "/code/.hidden/secret": "https://github.com/org/secret.git",
            "/code/a/front/inner": "https://github.com/org/inner.git"
        ])
        let scanned = await CloneLocator(root: root, fileSystem: fs, runner: runner).scan()
        #expect(Set(scanned.keys) == ["org/front", "org/deeper"])
        #expect(scanned["org/front"] == [URL(fileURLWithPath: "/code/a/front")])
    }

    @Test func worktreeGitFileCountsAsRepo() async {
        let fs = FakeFileSystem(tree: ["/code": ["wt"]], gitMarkers: ["/code/wt/.git"])
        let runner = RemoteRunner(remotes: ["/code/wt": "git@github.com:org/wt.git"])
        let scanned = await CloneLocator(root: root, fileSystem: fs, runner: runner).scan()
        #expect(scanned["org/wt"] == [URL(fileURLWithPath: "/code/wt")])
    }

    @Test func multipleClonesAreSortedAndFailedRemotesSkipped() async {
        let fs = FakeFileSystem(
            tree: ["/code": ["y", "x", "z"], "/code/x": ["f"], "/code/y": ["f"], "/code/z": ["f"]],
            gitMarkers: ["/code/x/f/.git", "/code/y/f/.git", "/code/z/f/.git"]
        )
        let runner = RemoteRunner(remotes: [
            "/code/x/f": "git@github.com:org/f.git",
            "/code/y/f": "git@github.com:org/f.git"
        ])
        let scanned = await CloneLocator(root: root, fileSystem: fs, runner: runner).scan()
        #expect(scanned["org/f"]?.map(\.path) == ["/code/x/f", "/code/y/f"])
    }

    @Test func overrideWinsOverScan() {
        let scanned = ["org/f": [URL(fileURLWithPath: "/code/x/f")]]
        let override = URL(fileURLWithPath: "/elsewhere/f")
        #expect(CloneResolver.pick(repository: "Org/F", scanned: scanned, overrides: ["org/f": override]) == override)
    }

    @Test func multipleClonesPickAlphabeticalFirst() {
        let scanned = ["org/f": [URL(fileURLWithPath: "/code/y/f"), URL(fileURLWithPath: "/code/x/f")]]
        #expect(CloneResolver.pick(repository: "org/f", scanned: scanned, overrides: [:])?.path == "/code/x/f")
    }

    @Test func missingRepoReturnsNil() {
        #expect(CloneResolver.pick(repository: "org/none", scanned: [:], overrides: [:]) == nil)
    }
}
