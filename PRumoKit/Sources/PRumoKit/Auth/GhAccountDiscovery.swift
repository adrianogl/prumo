import Foundation

public struct GhAccountDiscovery: Sendable {
    private let runner: ProcessRunner
    private let environment: [String: String]
    private let home: URL
    private let readFile: @Sendable (URL) -> String?
    private let candidatePaths: [String]
    private let fileExists: @Sendable (String) -> Bool

    public init(
        runner: ProcessRunner,
        environment: [String: String],
        home: URL,
        readFile: @escaping @Sendable (URL) -> String?,
        candidatePaths: [String] = ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"],
        fileExists: @escaping @Sendable (String) -> Bool
    ) {
        self.runner = runner
        self.environment = environment
        self.home = home
        self.readFile = readFile
        self.candidatePaths = candidatePaths
        self.fileExists = fileExists
    }

    public func accounts() async -> [GhAccount] {
        guard let text = readFile(hostsFileURL()) else { return [] }
        return GhHostsFile.accounts(fromYAML: text)
    }

    public func activeLogin() async -> String? {
        await accounts().first(where: \.isActive)?.login
    }

    public func token(for login: String) async -> String? {
        guard login.range(of: #"^[A-Za-z0-9_-]+\z"#, options: .regularExpression) != nil else { return nil }
        guard let path = candidatePaths.first(where: fileExists) else { return nil }
        let host = GhHostsFile.githubHost

        if let result = try? await runner.run(path, ["auth", "token", "--hostname", host, "--user", login]),
           result.status == 0 {
            return clean(result.stdout)
        }
        guard await activeLogin() == login,
              let fallback = try? await runner.run(path, ["auth", "token", "--hostname", host]),
              fallback.status == 0 else { return nil }
        return clean(fallback.stdout)
    }

    private func hostsFileURL() -> URL {
        if let dir = nonEmpty(environment["GH_CONFIG_DIR"]) {
            return URL(fileURLWithPath: dir).appendingPathComponent("hosts.yml")
        }
        if let xdg = nonEmpty(environment["XDG_CONFIG_HOME"]) {
            return URL(fileURLWithPath: xdg).appendingPathComponent("gh/hosts.yml")
        }
        return home.appendingPathComponent(".config/gh/hosts.yml")
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private func clean(_ output: String) -> String? {
        let token = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return token.isEmpty ? nil : token
    }
}
