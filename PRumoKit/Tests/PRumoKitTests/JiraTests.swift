import Foundation
import Testing
@testable import PRumoKit

struct JiraTests {
    @Test func detectsKeyInTitle() {
        #expect(JiraKeyDetector.key(title: "feat(pedido): ON-1234 filtro", branch: "", prefixes: ["ON"]) == "ON-1234")
    }

    @Test func detectsLowercaseKeyInBranch() {
        #expect(JiraKeyDetector.key(title: "feat: filtro", branch: "feat/on-1234-filtro", prefixes: ["ON"]) == "ON-1234")
    }

    @Test func titleWinsOverBranch() {
        #expect(JiraKeyDetector.key(title: "ON-1 filtro", branch: "feat/ON-2", prefixes: ["ON"]) == "ON-1")
    }

    @Test func ignoresUnconfiguredPrefix() {
        #expect(JiraKeyDetector.key(title: "ABC-1", branch: "", prefixes: ["ON"]) == nil)
    }

    @Test func ignoresPrefixInsideWord() {
        #expect(JiraKeyDetector.key(title: "MON-12", branch: "", prefixes: ["ON"]) == nil)
        #expect(JiraKeyDetector.key(title: "ON-", branch: "", prefixes: ["ON"]) == nil)
        #expect(JiraKeyDetector.key(title: "ON-x", branch: "", prefixes: ["ON"]) == nil)
    }

    @Test func linkUsesNormalizedHost() {
        let settings = JiraSettings(sites: [JiraSite(prefix: "on", host: " https://empresa.atlassian.net/ ")])
        let pr = PullRequest.fixture(title: "feat: ON-1234 filtro")
        #expect(settings.link(for: pr)?.url == URL(string: "https://empresa.atlassian.net/browse/ON-1234"))
    }

    @Test func emptyHostGivesKeyWithoutURL() {
        let settings = JiraSettings(sites: [JiraSite(prefix: "DEV", host: "")])
        let pr = PullRequest.fixture(title: "DEV-7 ajuste")
        #expect(settings.link(for: pr) == JiraLink(key: "DEV-7", url: nil))
    }

    @Test func invalidPrefixIsIgnored() {
        #expect(JiraKeyDetector.key(title: "o n-1", branch: "o-n-1", prefixes: ["o n"]) == nil)
    }

    @Test func firstSiteWinsForRepeatedPrefix() {
        let settings = JiraSettings(sites: [
            JiraSite(prefix: "ON", host: "a.atlassian.net"),
            JiraSite(prefix: "ON", host: "b.atlassian.net")
        ])
        let pr = PullRequest.fixture(title: "ON-5")
        #expect(settings.link(for: pr)?.url == URL(string: "https://a.atlassian.net/browse/ON-5"))
    }

    @Test func prWithoutKeyHasNoLink() {
        #expect(JiraSettings.defaults.link(for: PullRequest.fixture()) == nil)
    }

    @Test func defaultsMatchSpec() {
        #expect(JiraSettings.defaults.sites.map(\.prefix) == ["ON", "DEV"])
        #expect(JiraSettings.defaults.sites.map(\.host) == ["empresa.atlassian.net", ""])
    }

    @Test func settingsRoundTripCodable() throws {
        let data = try JSONEncoder().encode(JiraSettings.defaults)
        #expect(try JSONDecoder().decode(JiraSettings.self, from: data) == JiraSettings.defaults)
    }
}
