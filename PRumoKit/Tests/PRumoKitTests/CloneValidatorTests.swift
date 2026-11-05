import Foundation
import Testing
@testable import PRumoKit

private struct StubRunner: ProcessRunner {
    let expected: String
    let result: (status: Int32, stdout: String, stderr: String)
    var fails = false

    func run(_ executable: String, _ args: [String]) async throws -> (status: Int32, stdout: String, stderr: String) {
        if fails { throw ProcessRunnerError.timedOut }
        let line = ([executable] + args).joined(separator: " ")
        return line == expected ? result : (128, "", "comando inesperado")
    }
}

private let folder = URL(fileURLWithPath: "/Users/ana/Code/loja")
private let command = "/usr/bin/git -C /Users/ana/Code/loja remote get-url origin"

@Suite struct CloneValidatorTests {
    @Test func matchingOriginIsAccepted() async {
        let runner = StubRunner(expected: command, result: (0, "git@github.com:Acme/Loja.git\n", ""))
        #expect(await CloneValidator.isClone(of: "acme/loja", directory: folder, runner: runner))
    }

    @Test func otherRepositoryIsRejected() async {
        let runner = StubRunner(expected: command, result: (0, "https://github.com/outra/loja.git\n", ""))
        #expect(await !CloneValidator.isClone(of: "acme/loja", directory: folder, runner: runner))
    }

    @Test func folderWithoutOriginIsRejected() async {
        let runner = StubRunner(expected: command, result: (2, "", "error: No such remote 'origin'"))
        #expect(await !CloneValidator.isClone(of: "acme/loja", directory: folder, runner: runner))
    }

    @Test func runnerErrorIsRejected() async {
        let runner = StubRunner(expected: command, result: (0, "", ""), fails: true)
        #expect(await !CloneValidator.isClone(of: "acme/loja", directory: folder, runner: runner))
    }
}
