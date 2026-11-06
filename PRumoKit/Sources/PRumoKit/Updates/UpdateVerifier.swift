import CryptoKit
import Foundation

public enum UpdateVerifier {
    public static func sha256(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func matches(_ data: Data, checksum: String) -> Bool {
        guard let expected = expectedHash(checksum) else { return false }
        return sha256(of: data) == expected
    }

    public static func matches(fileAt url: URL, checksum: String) -> Bool {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return false }
        return matches(data, checksum: checksum)
    }

    private static func expectedHash(_ checksum: String) -> String? {
        let first = checksum.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: \.isWhitespace).first
            .map { $0.lowercased() }
        guard let first, !first.isEmpty else { return nil }
        return first
    }
}
