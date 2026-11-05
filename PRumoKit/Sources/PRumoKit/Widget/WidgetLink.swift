import Foundation

public enum WidgetLink {
    private static let scheme = "prumo"
    private static let host = "open"
    private static let queryName = "url"
    private static let allowedScheme = "https"
    private static let allowedHost = "github.com"

    public static func make(_ url: URL) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [URLQueryItem(name: queryName, value: url.absoluteString)]
        return components.url ?? url
    }

    public static func target(from url: URL) -> URL? {
        guard url.scheme == scheme, url.host == host,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let value = components.queryItems?.first(where: { $0.name == queryName })?.value,
              let target = URL(string: value),
              target.scheme == allowedScheme, target.host?.lowercased() == allowedHost
        else { return nil }
        return target
    }
}
