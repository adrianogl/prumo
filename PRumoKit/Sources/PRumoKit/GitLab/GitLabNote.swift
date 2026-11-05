import Foundation

struct GitLabNote: Decodable, Equatable, Sendable {
    let id: String
    let body: String
    let system: Bool
    let createdAt: Date
    let url: URL?
    let author: GitLabUser?

    init(id: String, body: String, system: Bool, createdAt: Date, url: URL?, author: GitLabUser?) {
        self.id = id
        self.body = body
        self.system = system
        self.createdAt = createdAt
        self.url = url
        self.author = author
    }

    private enum CodingKeys: String, CodingKey {
        case id, body, system, createdAt, url, author
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        body = try container.decode(String.self, forKey: .body)
        system = try container.decode(Bool.self, forKey: .system)
        url = try container.decodeIfPresent(URL.self, forKey: .url)
        author = try container.decodeIfPresent(GitLabUser.self, forKey: .author)
        let raw = try container.decode(String.self, forKey: .createdAt)
        guard let date = Self.parseDate(raw) else {
            throw DecodingError.dataCorruptedError(forKey: .createdAt, in: container, debugDescription: "Data inválida: \(raw)")
        }
        createdAt = date
    }

    private static func parseDate(_ raw: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: raw) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: raw)
    }
}
