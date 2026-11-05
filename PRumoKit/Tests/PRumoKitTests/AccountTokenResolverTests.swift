import Foundation
import Testing
@testable import PRumoKit

private final class Requested: @unchecked Sendable {
    private let lock = NSLock()
    private var ids: [String] = []
    func add(_ id: String) { lock.withLock { ids.append(id) } }
    var all: [String] { lock.withLock { ids } }
}

private struct FakeStore: TokenStore {
    var token: String?
    func read() -> String? { token }
    func write(_ token: String) throws {}
    func delete() throws {}
}

private struct ScriptedRunner: ProcessRunner {
    var status: Int32 = 0
    var stdout: String = ""
    var users: Requested = Requested()
    func run(_ executable: String, _ args: [String]) async throws -> (status: Int32, stdout: String, stderr: String) {
        if let index = args.firstIndex(of: "--user") { users.add(args[index + 1]) }
        return (status, stdout, "")
    }
}

private func discovery(_ runner: ScriptedRunner) -> GhAccountDiscovery {
    GhAccountDiscovery(
        runner: runner,
        environment: [:],
        home: URL(fileURLWithPath: "/Users/fake"),
        readFile: { _ in nil },
        candidatePaths: ["/fake/gh"],
        fileExists: { _ in true }
    )
}

private func glabDiscovery(_ runner: ScriptedRunner) -> GlabAccountDiscovery {
    GlabAccountDiscovery(
        runner: runner,
        environment: [:],
        home: URL(fileURLWithPath: "/Users/fake"),
        readFile: { _ in nil },
        candidatePaths: ["/fake/glab"],
        fileExists: { _ in true }
    )
}

private struct GlabHostRunner: ProcessRunner {
    let hosts: Requested
    func run(_ executable: String, _ args: [String]) async throws -> (status: Int32, stdout: String, stderr: String) {
        if let index = args.firstIndex(of: "--host") { hosts.add(args[index + 1]) }
        return (0, "glpat-corp\n", "")
    }
}

@Suite struct AccountTokenResolverTests {
    @Test func pastedAccountReadsOwnKeychainItem() async {
        let requested = Requested()
        let resolver = AccountTokenResolver(
            tokenStore: { id in requested.add(id); return FakeStore(token: "tok-a2") },
            gh: discovery(ScriptedRunner()),
            glab: glabDiscovery(ScriptedRunner())
        )
        let token = await resolver.token(for: Account(id: "a2", login: "globex-dev", origin: .pasted))
        #expect(token == "tok-a2")
        #expect(requested.all == ["a2"])
    }

    @Test func pastedAccountWithEmptyTokenIsNil() async {
        let resolver = AccountTokenResolver(tokenStore: { _ in FakeStore(token: "") }, gh: discovery(ScriptedRunner()), glab: glabDiscovery(ScriptedRunner()))
        #expect(await resolver.token(for: Account(id: "a2", login: "globex-dev", origin: .pasted)) == nil)
    }

    @Test func ghAccountAsksGhForThatUser() async {
        let runner = ScriptedRunner(stdout: "gho_globex\n")
        let resolver = AccountTokenResolver(
            tokenStore: { _ in FakeStore(token: "should-not-be-used") },
            gh: discovery(runner),
            glab: glabDiscovery(runner)
        )
        let token = await resolver.token(for: Account(id: "a3", login: "globex-dev", origin: .ghCLI))
        #expect(token == "gho_globex")
        #expect(runner.users.all == ["globex-dev"])
    }

    @Test func ghAccountWithoutTokenIsNil() async {
        let resolver = AccountTokenResolver(
            tokenStore: { _ in FakeStore(token: "x") },
            gh: discovery(ScriptedRunner(status: 1)),
            glab: glabDiscovery(ScriptedRunner())
        )
        #expect(await resolver.token(for: Account(id: "a3", login: "globex-dev", origin: .ghCLI)) == nil)
    }

    @Test func emuGhAccountAsksGhForUnderscoreLogin() async {
        let runner = ScriptedRunner(stdout: "gho_emu\n")
        let resolver = AccountTokenResolver(tokenStore: { _ in FakeStore(token: nil) }, gh: discovery(runner), glab: glabDiscovery(runner))
        let token = await resolver.token(for: Account(id: "a4", login: "octo_acme", origin: .ghCLI))
        #expect(token == "gho_emu")
        #expect(runner.users.all == ["octo_acme"])
    }

    @Test func glabAccountAsksGlabForHost() async {
        let hosts = Requested()
        let resolver = AccountTokenResolver(
            tokenStore: { _ in FakeStore(token: "x") },
            gh: discovery(ScriptedRunner()),
            glab: GlabAccountDiscovery(
                runner: GlabHostRunner(hosts: hosts),
                environment: [:],
                home: URL(fileURLWithPath: "/Users/fake"),
                readFile: { _ in nil },
                candidatePaths: ["/fake/glab"],
                fileExists: { _ in true }
            )
        )
        let account = Account(id: "g1", provider: .gitlab, host: "gitlab.empresa.com", login: "adriano", origin: .glabCLI)
        #expect(await resolver.token(for: account) == "glpat-corp")
        #expect(hosts.all == ["gitlab.empresa.com"])
    }
}
