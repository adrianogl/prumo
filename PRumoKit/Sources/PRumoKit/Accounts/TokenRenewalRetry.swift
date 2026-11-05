public enum TokenRenewalRetry {
    public static func run<Value>(
        fetch: () async throws(ProviderError) -> Value,
        renew: () async -> Bool
    ) async throws(ProviderError) -> Value {
        do {
            return try await fetch()
        } catch .unauthorized {
            guard await renew() else { throw .unauthorized }
            return try await fetch()
        }
    }
}
