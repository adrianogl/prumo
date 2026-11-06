import Foundation

struct LatestReleaseResponse: Decodable {
    let tagName: String
    let body: String?
    let htmlURL: URL
    let assets: [ReleaseAsset]?

    private enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case body
        case htmlURL = "html_url"
        case assets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tagName = try container.decode(String.self, forKey: .tagName)
        htmlURL = try container.decode(URL.self, forKey: .htmlURL)
        body = try? container.decodeIfPresent(String.self, forKey: .body)
        assets = try? container.decodeIfPresent([ReleaseAsset].self, forKey: .assets)
    }
}
