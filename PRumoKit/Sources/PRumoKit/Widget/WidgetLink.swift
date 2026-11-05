import Foundation

public enum WidgetLink {
    private static let scheme = "prumo"
    private static let host = "open"
    private static let queryName = "url"
    private static let allowedScheme = "https"
    public static let defaultAllowedHosts: Set<String> = ["github.com"]

    public static func make(_ url: URL) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [URLQueryItem(name: queryName, value: url.absoluteString)]
        return components.url ?? url
    }

    public static func target(from url: URL, allowedHosts: Set<String> = defaultAllowedHosts) -> URL? {
        guard url.scheme == scheme, url.host == host,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let value = components.queryItems?.first(where: { $0.name == queryName })?.value,
              let target = URL(string: value),
              target.scheme == allowedScheme, let authority = authority(of: target),
              allowedHosts.contains(where: { $0.lowercased() == authority })
        else { return nil }
        return target
    }

    private static func authority(of url: URL) -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        return url.port.map { "\(host):\($0)" } ?? host
    }
}
