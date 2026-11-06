import Foundation

struct ReleaseAsset: Decodable {
    let name: String
    let url: URL?

    private enum CodingKeys: String, CodingKey {
        case name
        case url = "browser_download_url"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? ""
        url = try? container.decodeIfPresent(URL.self, forKey: .url)
    }
}
