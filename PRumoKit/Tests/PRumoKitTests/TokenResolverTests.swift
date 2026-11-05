import Testing
@testable import PRumoKit

private struct FakeRunner: ProcessRunner {
    var status: Int32 = 0
    var stdout: String = ""
    func run(_ executable: String, _ args: [String]) async throws -> (status: Int32, stdout: String) {
        (status, stdout)
    }
}

private struct FakeStore: TokenStore {
    var token: String?
    func read() -> String? { token }
    func write(_ token: String) throws {}
    func delete() throws {}
}

private func gh(_ runner: FakeRunner, installed: Bool = true) -> GhCLITokenSource {
    GhCLITokenSource(runner: runner, candidatePaths: ["/fake/gh"], fileExists: { _ in installed })
}

@Suite struct TokenResolverTests {
    @Test func prefersStoredToken() async {
        let resolver = TokenResolver(
            store: FakeStore(token: "ghp_stored"),
            gh: gh(FakeRunner(stdout: "gho_cli\n"))
        )
        let result = await resolver.resolve()
        #expect(result?.token == "ghp_stored")
        #expect(result?.origin == .pasted)
    }

    @Test func fallsBackToGh() async {
        let resolver = TokenResolver(store: FakeStore(token: nil), gh: gh(FakeRunner(stdout: "gho_cli\n")))
        let result = await resolver.resolve()
        #expect(result?.token == "gho_cli")
        #expect(result?.origin == .ghCLI)
    }

    @Test func ghNonZeroExitReturnsNil() async {
        let resolver = TokenResolver(store: FakeStore(token: nil), gh: gh(FakeRunner(status: 1, stdout: "x")))
        #expect(await resolver.resolve() == nil)
    }

    @Test func ghNotInstalledReturnsNil() async {
        let resolver = TokenResolver(
            store: FakeStore(token: nil),
            gh: gh(FakeRunner(stdout: "gho_cli"), installed: false)
        )
        #expect(await resolver.resolve() == nil)
    }

    @Test func trimsNewline() async {
        let token = await gh(FakeRunner(stdout: "gho_abc\n")).token()
        #expect(token == "gho_abc")
    }
}
