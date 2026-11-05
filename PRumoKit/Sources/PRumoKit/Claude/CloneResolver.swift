import Foundation

public enum CloneResolver {
    public static func pick(repository: String, scanned: [String: [URL]], overrides: [String: URL]) -> URL? {
        let key = repository.lowercased()
        if let override = overrides[key] { return override }
        return scanned[key]?.min { $0.path < $1.path }
    }
}
