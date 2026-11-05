public struct GlabLoginState: Equatable, Sendable {
    public private(set) var logins: [String: String] = [:]
    public private(set) var unauthenticatedHosts: Set<String> = []
    private var networkHosts: Set<String> = []

    public init() {}

    public mutating func apply(host: String, configLogin: String?, accountCount: Int) -> GlabLoginStep {
        if let configLogin {
            logins[host] = configLogin
            unauthenticatedHosts.remove(host)
            networkHosts.remove(host)
            return .done
        }
        if !networkHosts.contains(host) {
            logins.removeValue(forKey: host)
        }
        guard accountCount > 1 else { return .done }
        if networkHosts.contains(host), !unauthenticatedHosts.contains(host) { return .done }
        return .checkToken
    }

    public mutating func tokenChecked(host: String, hasToken: Bool) -> GlabLoginStep {
        networkHosts.insert(host)
        guard hasToken else {
            unauthenticatedHosts.insert(host)
            return .done
        }
        unauthenticatedHosts.remove(host)
        return .resolveByNetwork
    }

    public mutating func networkResolved(host: String, login: String?) {
        guard let login else { return }
        logins[host] = login
    }
}
