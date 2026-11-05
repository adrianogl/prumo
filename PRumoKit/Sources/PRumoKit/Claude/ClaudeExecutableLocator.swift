import Foundation

public enum ClaudeExecutableLocator {
    private actor Cache {
        var found = false

        func markFound() {
            found = true
        }
    }

    private static let cache = Cache()

    public static func isAvailable(runner: ProcessRunner) async throws -> Bool {
        let result = try await runner.run("/bin/zsh", ["-ilc", "whence claude"])
        return result.status == 0 && !result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public static func cached(runner: ProcessRunner) async throws -> Bool {
        if await cache.found { return true }
        guard try await isAvailable(runner: runner) else { return false }
        await cache.markFound()
        return true
    }
}
