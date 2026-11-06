import Foundation

public struct ReleaseInfo: Equatable, Sendable {
    public let version: AppVersion
    public let notes: String
    public let pageURL: URL
    public let dmgURL: URL?
    public let checksumURL: URL?

    public init(version: AppVersion, notes: String, pageURL: URL, dmgURL: URL?, checksumURL: URL?) {
        self.version = version
        self.notes = notes
        self.pageURL = pageURL
        self.dmgURL = dmgURL
        self.checksumURL = checksumURL
    }

    public var isInstallable: Bool {
        dmgURL != nil && checksumURL != nil
    }

    static func decode(_ data: Data) -> ReleaseInfo? {
        guard let response = try? JSONDecoder().decode(LatestReleaseResponse.self, from: data),
              let version = AppVersion(response.tagName)
        else { return nil }
        let assets = response.assets ?? []
        func asset(_ name: String) -> URL? {
            assets.first { $0.name == name }?.url
        }
        return ReleaseInfo(
            version: version,
            notes: response.body ?? "",
            pageURL: response.htmlURL,
            dmgURL: asset(UpdateConstants.dmgAssetName),
            checksumURL: asset(UpdateConstants.checksumAssetName))
    }
}
