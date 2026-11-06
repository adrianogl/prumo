import Foundation
import Testing
@testable import PRumoKit

private final class InstallRunner: ProcessRunner, @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [String] = []
    private let failing: Set<String>

    init(failing: Set<String> = []) {
        self.failing = failing
    }

    var commands: [String] {
        lock.withLock { recorded }
    }

    func run(_ executable: String, _ args: [String]) async throws -> (status: Int32, stdout: String, stderr: String) {
        let line = ([executable] + args).joined(separator: " ")
        lock.withLock { recorded.append(line) }
        let name = URL(fileURLWithPath: executable).lastPathComponent
        let verb = args.first ?? ""
        if failing.contains(name) || failing.contains("\(name) \(verb)") { return (1, "", "falhou") }
        return (0, "", "")
    }
}

private final class FakeUpdateFiles: UpdateFileManaging, @unchecked Sendable {
    private let lock = NSLock()
    private var log: [String] = []
    private var written: [String: Data] = [:]
    var writable = true
    var existing: Set<String> = ["/mnt/work/mount/PRumo.app"]
    var failing: Set<String> = []
    var infos: [String: [String: String]] = [
        "/Applications/PRumo.app": ["CFBundleIdentifier": "dev.aglv.prumo", "CFBundleShortVersionString": "0.2.0"],
        "/Applications/.PRumo-0.3.0.app": ["CFBundleIdentifier": "dev.aglv.prumo", "CFBundleShortVersionString": "0.3.0"],
    ]

    var operations: [String] {
        lock.withLock { log }
    }

    func data(at path: String) -> Data? {
        lock.withLock { written[path] }
    }

    private func record(_ line: String) throws {
        lock.withLock { log.append(line) }
        if failing.contains(line.components(separatedBy: " ").first ?? "") {
            throw CocoaError(.fileWriteNoPermission)
        }
    }

    func isWritable(_ url: URL) -> Bool { writable }

    func exists(_ url: URL) -> Bool { existing.contains(url.path) }

    func infoDictionary(ofApp url: URL) -> [String: String]? { infos[url.path] }

    func createDirectory(_ url: URL) throws { try record("mkdir \(url.path)") }

    func write(_ data: Data, to url: URL) throws {
        try record("write \(url.path)")
        lock.withLock { written[url.path] = data }
    }

    func copyItem(at source: URL, to destination: URL) throws { try record("copy \(source.path) \(destination.path)") }

    func replaceItem(at original: URL, with replacement: URL) throws {
        try record("replace \(original.path) \(replacement.path)")
    }

    func removeItem(_ url: URL) { try? record("remove \(url.path)") }
}

private let dmgData = Data("dmg".utf8)
private let appURL = URL(fileURLWithPath: "/Applications/PRumo.app")
private let work = URL(fileURLWithPath: "/mnt/work")

private func release(dmg: Bool = true) -> ReleaseInfo {
    ReleaseInfo(
        version: AppVersion("0.3.0")!,
        notes: "",
        pageURL: URL(string: "https://github.com/adrianogl/prumo/releases/tag/v0.3.0")!,
        dmgURL: dmg ? URL(string: "https://example.com/PRumo.dmg") : nil,
        checksumURL: URL(string: "https://example.com/PRumo.dmg.sha256"))
}

private func transport(checksum: String, status: Int = 200) -> FakeTransport {
    FakeTransport { request in
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: [:])!
        if request.url?.pathExtension == "sha256" { return (Data(checksum.utf8), response) }
        return (dmgData, response)
    }
}

private func installer(
    runner: InstallRunner = InstallRunner(), files: FakeUpdateFiles = FakeUpdateFiles(), checksum: String? = nil, status: Int = 200
) -> UpdateInstaller {
    UpdateInstaller(
        runner: runner,
        transport: transport(checksum: checksum ?? "\(UpdateVerifier.sha256(of: dmgData))  PRumo.dmg\n", status: status),
        files: files)
}

@Suite struct UpdateInstallerTests {
    @Test func installsAndSchedulesRelaunch() async throws {
        let runner = InstallRunner()
        let files = FakeUpdateFiles()
        try await installer(runner: runner, files: files).install(release(), replacing: appURL, workDirectory: work, processID: 42)

        #expect(files.data(at: "/mnt/work/PRumo.dmg") == dmgData)
        #expect(files.operations.contains("copy /mnt/work/mount/PRumo.app /Applications/.PRumo-0.3.0.app"))
        #expect(files.operations.contains("replace /Applications/PRumo.app /Applications/.PRumo-0.3.0.app"))
        #expect(files.operations.last == "remove /mnt/work")
        #expect(runner.commands == [
            "/usr/bin/hdiutil attach -nobrowse -readonly -mountpoint /mnt/work/mount /mnt/work/PRumo.dmg",
            "/usr/bin/hdiutil detach /mnt/work/mount -force",
            "/usr/bin/xattr -dr com.apple.quarantine /Applications/PRumo.app",
            "/bin/sh -c \(UpdateConstants.relaunchScript) sh 42 /Applications/PRumo.app",
        ])
    }

    @Test func checksumMismatchInstallsNothing() async {
        let runner = InstallRunner()
        let files = FakeUpdateFiles()
        await #expect(throws: UpdateInstallError.checksumMismatch) {
            try await installer(runner: runner, files: files, checksum: String(repeating: "0", count: 64))
                .install(release(), replacing: appURL, workDirectory: work, processID: 42)
        }
        #expect(runner.commands.isEmpty)
        #expect(!files.operations.contains { $0.hasPrefix("replace") })
    }

    @Test func notWritableStopsBeforeDownload() async {
        let files = FakeUpdateFiles()
        files.writable = false
        let runner = InstallRunner()
        await #expect(throws: UpdateInstallError.notWritable) {
            try await installer(runner: runner, files: files)
                .install(release(), replacing: appURL, workDirectory: work, processID: 42)
        }
        #expect(files.operations.isEmpty)
        #expect(runner.commands.isEmpty)
    }

    @Test func releaseWithoutDMGIsRejected() async {
        await #expect(throws: UpdateInstallError.notInstallable) {
            try await installer().install(release(dmg: false), replacing: appURL, workDirectory: work, processID: 42)
        }
    }

    @Test func downloadFailureIsReported() async {
        await #expect(throws: UpdateInstallError.downloadFailed) {
            try await installer(status: 404).install(release(), replacing: appURL, workDirectory: work, processID: 42)
        }
    }

    @Test func mountFailureDoesNotReplace() async {
        let runner = InstallRunner(failing: ["hdiutil attach"])
        let files = FakeUpdateFiles()
        await #expect(throws: UpdateInstallError.mountFailed) {
            try await installer(runner: runner, files: files)
                .install(release(), replacing: appURL, workDirectory: work, processID: 42)
        }
        #expect(!files.operations.contains { $0.hasPrefix("replace") })
        #expect(files.operations.last == "remove /mnt/work")
    }

    @Test func missingAppInImageDetachesAndFails() async {
        let runner = InstallRunner()
        let files = FakeUpdateFiles()
        files.existing = []
        await #expect(throws: UpdateInstallError.copyFailed) {
            try await installer(runner: runner, files: files)
                .install(release(), replacing: appURL, workDirectory: work, processID: 42)
        }
        #expect(runner.commands.last == "/usr/bin/hdiutil detach /mnt/work/mount -force")
    }

    @Test func replaceFailureCleansStagingAndDetaches() async {
        let runner = InstallRunner()
        let files = FakeUpdateFiles()
        files.failing = ["replace"]
        await #expect(throws: UpdateInstallError.replaceFailed) {
            try await installer(runner: runner, files: files)
                .install(release(), replacing: appURL, workDirectory: work, processID: 42)
        }
        #expect(runner.commands.contains("/usr/bin/hdiutil detach /mnt/work/mount -force"))
        #expect(files.operations.contains("remove /Applications/.PRumo-0.3.0.app"))
        #expect(!runner.commands.contains { $0.hasPrefix("/bin/sh") })
    }

    @Test func wrongBundleIdentifierIsRejected() async {
        let runner = InstallRunner()
        let files = FakeUpdateFiles()
        files.infos["/Applications/.PRumo-0.3.0.app"] = ["CFBundleIdentifier": "outro.app", "CFBundleShortVersionString": "0.3.0"]
        await #expect(throws: UpdateInstallError.packageMismatch) {
            try await installer(runner: runner, files: files)
                .install(release(), replacing: appURL, workDirectory: work, processID: 42)
        }
        #expect(!files.operations.contains { $0.hasPrefix("replace") })
        #expect(files.operations.contains("remove /Applications/.PRumo-0.3.0.app"))
        #expect(!runner.commands.contains { $0.hasPrefix("/bin/sh") })
    }

    @Test func wrongVersionIsRejected() async {
        let files = FakeUpdateFiles()
        files.infos["/Applications/.PRumo-0.3.0.app"] = ["CFBundleIdentifier": "dev.aglv.prumo", "CFBundleShortVersionString": "0.2.0"]
        await #expect(throws: UpdateInstallError.packageMismatch) {
            try await installer(files: files).install(release(), replacing: appURL, workDirectory: work, processID: 42)
        }
        #expect(!files.operations.contains { $0.hasPrefix("replace") })
    }

    @Test func unreadableInfoPlistIsRejected() async {
        let files = FakeUpdateFiles()
        files.infos["/Applications/.PRumo-0.3.0.app"] = nil
        await #expect(throws: UpdateInstallError.packageMismatch) {
            try await installer(files: files).install(release(), replacing: appURL, workDirectory: work, processID: 42)
        }
        #expect(!files.operations.contains { $0.hasPrefix("replace") })
    }

    @Test func quarantineFailureIsIgnored() async throws {
        let runner = InstallRunner(failing: ["xattr"])
        try await installer(runner: runner).install(release(), replacing: appURL, workDirectory: work, processID: 42)
        #expect(runner.commands.last?.hasPrefix("/bin/sh") == true)
    }

    @Test func relaunchFailureIsReported() async {
        let runner = InstallRunner(failing: ["sh"])
        await #expect(throws: UpdateInstallError.relaunchFailed) {
            try await installer(runner: runner).install(release(), replacing: appURL, workDirectory: work, processID: 42)
        }
    }

    @Test func relaunchScriptWaitsForProcessAndOpensApp() {
        #expect(UpdateConstants.relaunchScript.contains("kill -0 \"$1\""))
        #expect(UpdateConstants.relaunchScript.contains("/usr/bin/open -n \"$2\""))
        #expect(UpdateConstants.relaunchScript.hasSuffix("&"))
    }
}
