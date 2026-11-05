import Foundation
import Testing
@testable import PRumoKit

private final class Calls: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [[String]] = []
    func add(_ args: [String]) { lock.lock(); stored.append(args); lock.unlock() }
    var all: [[String]] { lock.lock(); defer { lock.unlock() }; return stored }
}

private struct ScriptedRunner: ProcessRunner {
    let calls: Calls
    let respond: @Sendable ([String]) -> (Int32, String)
    func run(_ executable: String, _ args: [String]) async throws -> (status: Int32, stdout: String, stderr: String) {
        calls.add(args)
        let (status, out) = respond(args)
        return (status, out, "")
    }
}

private func fixture(_ name: String) -> String {
    let url = Bundle.module.url(forResource: name, withExtension: "yml", subdirectory: "Fixtures")!
    return try! String(contentsOf: url, encoding: .utf8)
}

private func discovery(
    hosts: String? = nil,
    environment: [String: String] = [:],
    installed: Bool = true,
    calls: Calls = Calls(),
    respond: @escaping @Sendable ([String]) -> (Int32, String) = { _ in (0, "") },
    readPaths: PathLog = PathLog()
) -> GhAccountDiscovery {
    GhAccountDiscovery(
        runner: ScriptedRunner(calls: calls, respond: respond),
        environment: environment,
        home: URL(fileURLWithPath: "/Users/fake"),
        readFile: { url in readPaths.add(url.path); return hosts },
        candidatePaths: ["/fake/gh"],
        fileExists: { _ in installed }
    )
}

private final class PathLog: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [String] = []
    func add(_ path: String) { lock.lock(); stored.append(path); lock.unlock() }
    var all: [String] { lock.lock(); defer { lock.unlock() }; return stored }
}

@Suite struct GhAccountDiscoveryTests {
    @Test func parsesMultipleUsersAndActive() async {
        let accounts = await discovery(hosts: fixture("gh-hosts-multi")).accounts()
        #expect(accounts == [
            GhAccount(host: "github.com", login: "adrianogl", isActive: true),
            GhAccount(host: "github.com", login: "adriano-globex", isActive: false)
        ])
    }

    @Test func parsesLegacySingleUserFormat() async {
        let accounts = await discovery(hosts: fixture("gh-hosts-legacy")).accounts()
        #expect(accounts == [GhAccount(host: "github.com", login: "adrianogl", isActive: true)])
    }

    @Test func ignoresOtherHosts() async {
        let accounts = await discovery(hosts: fixture("gh-hosts-multi")).accounts()
        #expect(!accounts.contains { $0.login == "adriano-acme" })
    }

    @Test func normalizesHostFromGh() {
        #expect(GhHostsFile.normalizeHost("HTTPS://GitHub.com/") == "github.com")
        let accounts = GhHostsFile.accounts(fromYAML: "GitHub.com:\n    user: adrianogl\n")
        #expect(accounts.map(\.login) == ["adrianogl"])
    }

    @Test func configDirRespectsGhConfigDir() async {
        let log = PathLog()
        _ = await discovery(environment: ["GH_CONFIG_DIR": "/cfg/gh"], readPaths: log).accounts()
        _ = await discovery(environment: ["XDG_CONFIG_HOME": "/xdg"], readPaths: log).accounts()
        _ = await discovery(readPaths: log).accounts()
        #expect(log.all == ["/cfg/gh/hosts.yml", "/xdg/gh/hosts.yml", "/Users/fake/.config/gh/hosts.yml"])
    }

    @Test func tokenUsesUserFlag() async {
        let calls = Calls()
        let token = await discovery(hosts: fixture("gh-hosts-multi"), calls: calls, respond: { _ in (0, "gho_globex\n") })
            .token(for: "adriano-globex")
        #expect(token == "gho_globex")
        #expect(calls.all == [["auth", "token", "--hostname", "github.com", "--user", "adriano-globex"]])
    }

    @Test func tokenFallsBackToActiveWhenUserFlagUnsupported() async {
        let calls = Calls()
        let token = await discovery(hosts: fixture("gh-hosts-multi"), calls: calls, respond: { args in
            args.contains("--user") ? (1, "") : (0, "gho_active\n")
        }).token(for: "adrianogl")
        #expect(token == "gho_active")
        #expect(calls.all.last == ["auth", "token", "--hostname", "github.com"])
    }

    @Test func tokenNilForInactiveWhenUserFlagFails() async {
        let calls = Calls()
        let token = await discovery(hosts: fixture("gh-hosts-multi"), calls: calls, respond: { _ in (1, "") })
            .token(for: "adriano-globex")
        #expect(token == nil)
        #expect(calls.all.count == 1)
    }

    @Test func emptyOutputIsNil() async {
        let token = await discovery(hosts: fixture("gh-hosts-multi"), respond: { _ in (0, "  \n") })
            .token(for: "adrianogl")
        #expect(token == nil)
    }

    @Test func unsafeLoginNeverRuns() async {
        let calls = Calls()
        let token = await discovery(hosts: fixture("gh-hosts-multi"), calls: calls, respond: { _ in (0, "gho_x") })
            .token(for: "x; rm -rf ~")
        #expect(token == nil)
        #expect(calls.all.isEmpty)
    }

    @Test func emuLoginWithUnderscoreIsAccepted() async {
        let calls = Calls()
        let token = await discovery(hosts: fixture("gh-hosts-multi"), calls: calls, respond: { _ in (0, "gho_emu\n") })
            .token(for: "octo_acme")
        #expect(token == "gho_emu")
        #expect(calls.all == [["auth", "token", "--hostname", "github.com", "--user", "octo_acme"]])
    }

    @Test func emuLoginFallsBackToActiveToken() async {
        let hosts = "github.com:\n    users:\n        octo_acme:\n    user: octo_acme\n"
        let calls = Calls()
        let token = await discovery(hosts: hosts, calls: calls, respond: { args in
            args.contains("--user") ? (1, "") : (0, "gho_emu_active\n")
        }).token(for: "octo_acme")
        #expect(token == "gho_emu_active")
        #expect(calls.all.last == ["auth", "token", "--hostname", "github.com"])
    }

    @Test func loginWithTrailingNewlineNeverRuns() async {
        let calls = Calls()
        let token = await discovery(hosts: fixture("gh-hosts-multi"), calls: calls, respond: { _ in (0, "gho_x") })
            .token(for: "adrianogl\n")
        #expect(token == nil)
        #expect(calls.all.isEmpty)
    }

    @Test func noGhBinaryReturnsNoToken() async {
        let calls = Calls()
        let found = discovery(hosts: fixture("gh-hosts-multi"), installed: false, calls: calls, respond: { _ in (0, "gho_x") })
        #expect(await found.token(for: "adrianogl") == nil)
        #expect(await found.accounts().count == 2)
        #expect(calls.all.isEmpty)
    }
}
