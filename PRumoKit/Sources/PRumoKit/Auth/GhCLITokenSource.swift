import Foundation

public struct GhCLITokenSource: Sendable {
    private let runner: ProcessRunner
    private let candidatePaths: [String]
    private let fileExists: @Sendable (String) -> Bool

    public init(
        runner: ProcessRunner,
        candidatePaths: [String] = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"],
        fileExists: @escaping @Sendable (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) {
        self.runner = runner
        self.candidatePaths = candidatePaths
        self.fileExists = fileExists
    }

    public func token() async -> String? {
        guard let path = candidatePaths.first(where: fileExists) else { return nil }
        guard let result = try? await runner.run(path, ["auth", "token"]), result.status == 0 else {
            return nil
        }
        let token = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return token.isEmpty ? nil : token
    }
}
