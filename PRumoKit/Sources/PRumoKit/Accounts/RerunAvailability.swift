import Foundation

public enum RerunAvailability {
    private static let requiredScope = "api"
    private static let missingScopeReason = "Precisa de um token com escopo api. O desta conta só lê (read_api)."

    public static func disabledReason(provider: ProviderKind, scopes: [String]?) -> String? {
        guard provider == .gitlab, let scopes, !scopes.contains(requiredScope) else { return nil }
        return missingScopeReason
    }
}
