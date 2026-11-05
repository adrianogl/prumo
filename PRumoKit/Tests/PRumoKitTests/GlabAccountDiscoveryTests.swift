import Foundation
import Testing
@testable import PRumoKit

private final class Calls: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [[String]] = []
    func add(_ args: [String]) { lock.lock(); stored.append(args); lock.unlock() }
    var all: [[String]] { lock.lock(); defer { lock.unlock() }; return stored }
}

private final class PathLog: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [String] = []
    func add(_ path: String) { lock.lock(); stored.append(path); lock.unlock() }
    var all: [String] { lock.lock(); defer { lock.unlock() }; return stored }
}

private struct ScriptedRunner: ProcessRunner {
    let calls: Calls
    let respond: @Sendable ([String]) -> (Int32, String, String)
    func run(_ executable: String, _ args: [String]) async throws -> (status: Int32, stdout: String, stderr: String) {
        calls.add(args)
        let (status, out, err) = respond(args)
        return (status, out, err)
    }
}

private func fixture() -> String {
    let url = Bundle.module.url(forResource: "glab-config", withExtension: "yml", subdirectory: "Fixtures")!
    return try! String(contentsOf: url, encoding: .utf8)
}

private let oauthExpiry = ISO8601DateFormatter().date(from: "2026-11-05T21:04:20-03:00")!

private func discovery(
    config: String? = nil,
    environment: [String: String] = [:],
    installed: Bool = true,
    now: Date = oauthExpiry.addingTimeInterval(-3600),
    calls: Calls = Calls(),
    respond: @escaping @Sendable ([String]) -> (Int32, String, String) = { _ in (0, "", "") },
    readPaths: PathLog = PathLog()
) -> GlabAccountDiscovery {
    GlabAccountDiscovery(
        runner: ScriptedRunner(calls: calls, respond: respond),
        environment: environment,
        home: URL(fileURLWithPath: "/Users/fake"),
        readFile: { url in readPaths.add(url.path); return config },
        candidatePaths: ["/fake/glab"],
        fileExists: { _ in installed },
        now: { now }
    )
}

@Suite struct GlabAccountDiscoveryTests {
    @Test func parsesHostsAndUsers() async {
        let accounts = await discovery(config: fixture()).accounts()
        #expect(accounts.map(\.host) == ["gitlab.com", "gitlab.empresa.com"])
        #expect(accounts.map(\.login) == ["adriano", "adriano"])
    }

    @Test func parsesOAuthFlagAndExpiry() async {
        let accounts = await discovery(config: fixture()).accounts()
        #expect(accounts[0] == GlabAccount(host: "gitlab.com", login: "adriano", isOAuth: true, expiresAt: oauthExpiry))
        #expect(accounts[1] == GlabAccount(host: "gitlab.empresa.com", login: "adriano", isOAuth: false, expiresAt: nil))
    }

    @Test func ignoresCommentsAndQuotes() {
        let text = """
        hosts:
            gitlab.com:
                # user: someone-else
                user: "quoted"
                is_oauth2: "true"
                oauth2_expiry_date: "2026-11-05T21:04:20-03:00"
        """
        #expect(GlabConfigFile.accounts(fromYAML: text) == [
            GlabAccount(host: "gitlab.com", login: "quoted", isOAuth: true, expiresAt: oauthExpiry)
        ])
    }

    @Test func hostWithoutUserHasNilLogin() {
        let text = "hosts:\n  gitlab.empresa.com:\n    api_protocol: https\n"
        #expect(GlabConfigFile.accounts(fromYAML: text) == [GlabAccount(host: "gitlab.empresa.com", login: nil)])
    }

    @Test func noHostsBlockMeansNoAccounts() {
        #expect(GlabConfigFile.accounts(fromYAML: "git_protocol: ssh\n").isEmpty)
    }

    @Test func configDirOrder() async {
        let paths = PathLog()
        _ = await discovery(
            environment: ["GLAB_CONFIG_DIR": "/glab", "XDG_CONFIG_HOME": "/xdg"],
            readPaths: paths
        ).accounts()
        #expect(paths.all == [
            "/glab/config.yml",
            "/xdg/glab-cli/config.yml",
            "/Users/fake/Library/Application Support/glab-cli/config.yml",
            "/Users/fake/.config/glab-cli/config.yml"
        ])
    }

    @Test func tokenFromConfigGet() async {
        let calls = Calls()
        let token = await discovery(
            config: fixture(),
            calls: calls,
            respond: { _ in (0, "glpat-abc\n", "") }
        ).token(host: "gitlab.empresa.com")
        #expect(token == "glpat-abc")
        #expect(calls.all == [["config", "get", "token", "--host", "gitlab.empresa.com"]])
    }

    @Test func tokenFallsBackToAuthStatus() async {
        let calls = Calls()
        let token = await discovery(
            config: fixture(),
            calls: calls,
            respond: { args in
                args.first == "auth"
                    ? (0, "", "gitlab.empresa.com\n  ✓ Token: glpat-xyz\n")
                    : (0, "\n", "")
            }
        ).token(host: "gitlab.empresa.com")
        #expect(token == "glpat-xyz")
        #expect(calls.all.last == ["auth", "status", "--hostname", "gitlab.empresa.com", "--show-token"])
    }

    @Test func nothingFoundReturnsNil() async {
        let token = await discovery(config: fixture()).token(host: "gitlab.empresa.com")
        #expect(token == nil)
    }

    @Test func unsafeHostNeverRuns() async {
        let calls = Calls()
        let token = await discovery(config: fixture(), calls: calls, respond: { _ in (0, "tok", "") })
            .token(host: "gitlab.com; rm -rf /")
        #expect(token == nil)
        #expect(calls.all.isEmpty)
    }

    @Test func noGlabBinaryReturnsNoToken() async {
        let calls = Calls()
        let token = await discovery(config: fixture(), installed: false, calls: calls, respond: { _ in (0, "tok", "") })
            .token(host: "gitlab.com")
        #expect(token == nil)
        #expect(calls.all.isEmpty)
    }

    @Test func oauthNearExpiryRefreshesFirst() async {
        let calls = Calls()
        let token = await discovery(
            config: fixture(),
            now: oauthExpiry.addingTimeInterval(-60),
            calls: calls,
            respond: { args in args.first == "config" ? (0, "glpat-new\n", "") : (0, "ignored", "") }
        ).token(host: "gitlab.com")
        #expect(token == "glpat-new")
        #expect(calls.all == [
            ["api", "user", "--hostname", "gitlab.com"],
            ["config", "get", "token", "--host", "gitlab.com"]
        ])
    }

    @Test func oauthFarFromExpiryDoesNotRefresh() async {
        let calls = Calls()
        _ = await discovery(config: fixture(), calls: calls, respond: { _ in (0, "tok", "") }).token(host: "gitlab.com")
        #expect(calls.all == [["config", "get", "token", "--host", "gitlab.com"]])
    }

    @Test func oauthWithoutExpiryRefreshes() async {
        let calls = Calls()
        let text = "hosts:\n  gitlab.com:\n    is_oauth2: \"true\"\n"
        _ = await discovery(config: text, calls: calls, respond: { _ in (0, "tok", "") }).token(host: "gitlab.com")
        #expect(calls.all.first == ["api", "user", "--hostname", "gitlab.com"])
    }

    @Test func patTokenNeverRefreshes() async {
        let calls = Calls()
        _ = await discovery(
            config: fixture(),
            now: oauthExpiry.addingTimeInterval(3600),
            calls: calls,
            respond: { _ in (0, "tok", "") }
        ).token(host: "gitlab.empresa.com")
        #expect(calls.all == [["config", "get", "token", "--host", "gitlab.empresa.com"]])
    }

    @Test func accountForHostFindsOAuthAccount() async {
        let account = await discovery(config: fixture()).account(host: "gitlab.com")
        #expect(account?.isOAuth == true)
        #expect(await discovery(config: fixture()).account(host: "outro.com") == nil)
    }
}
