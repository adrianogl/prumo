public struct LegacyAccountState: Equatable, Sendable {
    public let login: String?
    public let origin: TokenOrigin?
    public let onboardingDone: Bool

    public init(login: String?, origin: TokenOrigin?, onboardingDone: Bool) {
        self.login = login
        self.origin = origin
        self.onboardingDone = onboardingDone
    }
}
