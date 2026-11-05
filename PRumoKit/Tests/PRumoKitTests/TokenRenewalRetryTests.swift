import Foundation
import Testing
@testable import PRumoKit

@Suite struct TokenRenewalRetryTests {
    private final class Calls: @unchecked Sendable {
        var fetches = 0
        var renewals = 0
    }

    @Test func retriesOnceWhenRenewalChangesToken() async throws {
        let calls = Calls()
        let value = try await TokenRenewalRetry.run(
            fetch: { () async throws(ProviderError) -> Int in
                calls.fetches += 1
                if calls.fetches == 1 { throw .unauthorized }
                return 7
            },
            renew: {
                calls.renewals += 1
                return true
            })
        #expect(value == 7)
        #expect(calls.fetches == 2)
        #expect(calls.renewals == 1)
    }

    @Test func keepsUnauthorizedWhenTokenDidNotChange() async {
        let calls = Calls()
        await #expect(throws: ProviderError.unauthorized) {
            try await TokenRenewalRetry.run(
                fetch: { () async throws(ProviderError) -> Int in
                    calls.fetches += 1
                    throw .unauthorized
                },
                renew: {
                    calls.renewals += 1
                    return false
                })
        }
        #expect(calls.fetches == 1)
        #expect(calls.renewals == 1)
    }

    @Test func secondUnauthorizedIsNotRetriedAgain() async {
        let calls = Calls()
        await #expect(throws: ProviderError.unauthorized) {
            try await TokenRenewalRetry.run(
                fetch: { () async throws(ProviderError) -> Int in
                    calls.fetches += 1
                    throw .unauthorized
                },
                renew: {
                    calls.renewals += 1
                    return true
                })
        }
        #expect(calls.fetches == 2)
        #expect(calls.renewals == 1)
    }

    @Test func otherErrorsDoNotRenew() async {
        let calls = Calls()
        await #expect(throws: ProviderError.network) {
            try await TokenRenewalRetry.run(
                fetch: { () async throws(ProviderError) -> Int in
                    calls.fetches += 1
                    throw .network
                },
                renew: {
                    calls.renewals += 1
                    return true
                })
        }
        #expect(calls.fetches == 1)
        #expect(calls.renewals == 0)
    }
}
