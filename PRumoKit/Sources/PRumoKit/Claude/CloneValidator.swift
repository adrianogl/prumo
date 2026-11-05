import Foundation

public enum CloneValidator {
    public static func isClone(of repository: String, directory: URL, runner: ProcessRunner, gitlabHosts: Set<String> = []) async -> Bool {
        guard let result = try? await runner.run("/usr/bin/git", ["-C", directory.path, "remote", "get-url", "origin"]),
              result.status == 0
        else { return false }
        return RemoteURL.repositoryKey(from: result.stdout, gitlabHosts: gitlabHosts) == repository.lowercased()
    }
}
