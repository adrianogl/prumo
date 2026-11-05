import Foundation

public struct GlabAccountDiscovery: Sendable {
    private static let refreshMargin: TimeInterval = 300

    private let runner: ProcessRunner
    private let environment: [String: String]
    private let home: URL
    private let readFile: @Sendable (URL) -> String?
    private let candidatePaths: [String]
    private let fileExists: @Sendable (String) -> Bool
    private let now: @Sendable () -> Date

    public init(
        runner: ProcessRunner,
        environment: [String: String],
        home: URL,
        readFile: @escaping @Sendable (URL) -> String?,
        candidatePaths: [String] = ["/opt/homebrew/bin/glab", "/usr/local/bin/glab"],
        fileExists: @escaping @Sendable (String) -> Bool,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.runner = runner
        self.environment = environment
        self.home = home
        self.readFile = readFile
        self.candidatePaths = candidatePaths
        self.fileExists = fileExists
        self.now = now
    }

    public func accounts() async -> [GlabAccount] {
        for url in configFileURLs() {
            if let text = readFile(url) { return GlabConfigFile.accounts(fromYAML: text) }
        }
        return []
    }

    public func account(host: String) async -> GlabAccount? {
        await accounts().first { $0.host == host }
    }

    public func token(host: String) async -> String? {
        guard host.range(of: #"^[A-Za-z0-9.-]+(:[0-9]+)?\z"#, options: .regularExpression) != nil else { return nil }
        guard let path = candidatePaths.first(where: fileExists) else { return nil }

        if let account = await account(host: host), account.isOAuth, needsRefresh(account) {
            _ = try? await runner.run(path, ["api", "user", "--hostname", host])
        }

        if let result = try? await runner.run(path, ["config", "get", "token", "--host", host]),
           result.status == 0, let token = clean(result.stdout) {
            return token
        }
        guard let status = try? await runner.run(path, ["auth", "status", "--hostname", host, "--show-token"]) else {
            return nil
        }
        return tokenLine(in: status.stderr) ?? tokenLine(in: status.stdout)
    }

    private func needsRefresh(_ account: GlabAccount) -> Bool {
        guard let expiresAt = account.expiresAt else { return true }
        return expiresAt.timeIntervalSince(now()) < Self.refreshMargin
    }

    private func configFileURLs() -> [URL] {
        var urls: [URL] = []
        if let dir = nonEmpty(environment["GLAB_CONFIG_DIR"]) {
            urls.append(URL(fileURLWithPath: dir).appendingPathComponent("config.yml"))
        }
        if let xdg = nonEmpty(environment["XDG_CONFIG_HOME"]) {
            urls.append(URL(fileURLWithPath: xdg).appendingPathComponent("glab-cli/config.yml"))
        }
        urls.append(home.appendingPathComponent("Library/Application Support/glab-cli/config.yml"))
        urls.append(home.appendingPathComponent(".config/glab-cli/config.yml"))
        return urls
    }

    private func tokenLine(in output: String) -> String? {
        for line in output.components(separatedBy: .newlines) {
            guard let range = line.range(of: "Token:") else { continue }
            if let token = clean(String(line[range.upperBound...])) { return token }
        }
        return nil
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
