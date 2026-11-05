import Testing
@testable import PRumoKit

@Suite struct GlabLoginStateTests {
    private let host = "gitlab.com"

    @Test func logoutClearsLogin() {
        var state = GlabLoginState()
        _ = state.apply(host: host, configLogin: "antigo", accountCount: 2)
        #expect(state.logins[host] == "antigo")
        let step = state.apply(host: host, configLogin: nil, accountCount: 2)
        #expect(state.logins[host] == nil)
        #expect(step == .checkToken)
    }

    @Test func networkLoginSurvivesRefreshWithoutConfigUser() {
        var state = GlabLoginState()
        #expect(state.apply(host: host, configLogin: nil, accountCount: 2) == .checkToken)
        #expect(state.tokenChecked(host: host, hasToken: true) == .resolveByNetwork)
        state.networkResolved(host: host, login: "rede")
        #expect(state.apply(host: host, configLogin: nil, accountCount: 2) == .done)
        #expect(state.logins[host] == "rede")
    }

    @Test func loginAfterUnauthenticatedIsRetried() {
        var state = GlabLoginState()
        _ = state.apply(host: host, configLogin: nil, accountCount: 2)
        #expect(state.tokenChecked(host: host, hasToken: false) == .done)
        #expect(state.unauthenticatedHosts.contains(host))
        #expect(state.apply(host: host, configLogin: nil, accountCount: 2) == .checkToken)
        #expect(state.tokenChecked(host: host, hasToken: true) == .resolveByNetwork)
        #expect(!state.unauthenticatedHosts.contains(host))
    }

    @Test func singleAccountSkipsResolution() {
        var state = GlabLoginState()
        #expect(state.apply(host: host, configLogin: nil, accountCount: 1) == .done)
        #expect(state.apply(host: host, configLogin: nil, accountCount: 0) == .done)
    }
}
