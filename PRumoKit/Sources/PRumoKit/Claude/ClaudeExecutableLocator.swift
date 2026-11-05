import Foundation

public enum ClaudeExecutableLocator {
    private actor Cache {
        var found = Set<String>()

        func contains(_ command: String) -> Bool {
            found.contains(command)
        }

        func markFound(_ command: String) {
            found.insert(command)
        }
    }

    private static let cache = Cache()

    public static func isAvailable(command: String, runner: ProcessRunner) async throws -> Bool {
        let result = try await runner.run("/bin/zsh", ["-ilc", "whence -- \(ShellQuote.single(command))"])
        return result.status == 0 && !result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public static func cached(command: String, runner: ProcessRunner) async throws -> Bool {
        if await cache.contains(command) { return true }
        guard try await isAvailable(command: command, runner: runner) else { return false }
        await cache.markFound(command)
        return true
    }
}
