import Testing
@testable import PRumoKit

@Suite struct RerunAvailabilityTests {
    @Test func rerunDisabledWithoutApiScope() {
        let reason = RerunAvailability.disabledReason(provider: .gitlab, scopes: ["read_api", "read_user"])
        #expect(reason == "Precisa de um token com escopo api. O desta conta só lê (read_api).")
    }

    @Test func rerunEnabledWhenScopesUnknown() {
        #expect(RerunAvailability.disabledReason(provider: .gitlab, scopes: nil) == nil)
    }

    @Test func rerunEnabledWithApiScope() {
        #expect(RerunAvailability.disabledReason(provider: .gitlab, scopes: ["api"]) == nil)
    }

    @Test func githubRerunUnaffected() {
        #expect(RerunAvailability.disabledReason(provider: .github, scopes: ["repo"]) == nil)
    }
}
