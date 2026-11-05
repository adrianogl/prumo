import Foundation

public enum ClaudeExecutableLocator {
    private actor Cache {
        var value: String?

        func store(_ path: String) {
            value = path
        }
    }

    private static let cache = Cache()

    public static func locate(runner: ProcessRunner) async -> String? {
        guard let result = try? await runner.run("/bin/zsh", ["-ilc", "command -v claude"]), result.status == 0 else {
            return nil
        }
        let path = result.stdout.split(separator: "\n").last.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        return path.hasPrefix("/") ? path : nil
    }

    public static func cached(runner: ProcessRunner) async -> String? {
        if let value = await cache.value { return value }
        guard let path = await locate(runner: runner) else { return nil }
        await cache.store(path)
        return path
    }
}
