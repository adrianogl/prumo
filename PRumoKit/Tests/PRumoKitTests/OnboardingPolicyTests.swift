import Foundation
import Testing
@testable import PRumoKit

@Suite struct OnboardingPolicyTests {
    private let github = Account(id: "a1", login: "adrianogl", origin: .pasted)
    private let githubCLI = Account(id: "a2", login: "adrianogl", origin: .ghCLI)
    private let gitlab = Account(id: "g1", provider: .gitlab, host: "gitlab.empresa.com", login: "adriano", origin: .pasted)
    private let gitlabCLI = Account(id: "g2", provider: .gitlab, host: "gitlab.empresa.com", login: "adriano", origin: .glabCLI)

    @Test func noAccountNeedsOnboarding() {
        #expect(OnboardingPolicy.needsOnboarding(accounts: [], tokens: [:]))
    }

    @Test func pastedGitHubWithoutTokenNeedsOnboarding() {
        #expect(OnboardingPolicy.needsOnboarding(accounts: [github], tokens: [:]))
        #expect(!OnboardingPolicy.needsOnboarding(accounts: [github], tokens: ["a1": "t"]))
        #expect(!OnboardingPolicy.needsOnboarding(accounts: [githubCLI], tokens: [:]))
    }

    @Test func gitLabWithoutTokenDoesNotNeedOnboarding() {
        #expect(!OnboardingPolicy.needsOnboarding(accounts: [gitlab], tokens: [:]))
        #expect(!OnboardingPolicy.needsOnboarding(accounts: [gitlabCLI], tokens: [:]))
    }

    @Test func onboardingReplacesOnlyGitHubAccounts() {
        #expect(OnboardingPolicy.onboardingReplacesAccounts([]))
        #expect(OnboardingPolicy.onboardingReplacesAccounts([github]))
        #expect(!OnboardingPolicy.onboardingReplacesAccounts([gitlab]))
        #expect(!OnboardingPolicy.onboardingReplacesAccounts([github, githubCLI]))
    }

    @Test func recoveryDependsOnProviderAndOrigin() {
        #expect(OnboardingPolicy.recovery(for: github) == .onboarding)
        #expect(OnboardingPolicy.recovery(for: githubCLI) == .onboarding)
        #expect(OnboardingPolicy.recovery(for: gitlab) == .settings)
        #expect(OnboardingPolicy.recovery(for: gitlabCLI) == .reconnect)
    }
}
