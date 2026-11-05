import Testing
@testable import PRumoKit

@Suite struct CheckoutWarningTests {
    private let account = Account(id: "a", login: "Adriano", origin: .ghCLI)

    @Test func noWarningWithOneAccount() {
        #expect(CheckoutWarning.text(account: account, activeLogin: "outra", accountCount: 1) == nil)
    }

    @Test func noWarningWithoutAccount() {
        #expect(CheckoutWarning.text(account: nil, activeLogin: "outra", accountCount: 2) == nil)
    }

    @Test func noWarningWhenActive() {
        #expect(CheckoutWarning.text(account: account, activeLogin: "adriano", accountCount: 2) == nil)
    }

    @Test func warningNamesSwitchCommand() {
        #expect(
            CheckoutWarning.text(account: account, activeLogin: "outra", accountCount: 2)
                == "A conta ativa do gh é @outra. Rode gh auth switch --user Adriano antes de colar o comando.")
    }

    @Test func warningWhenGhNotLogged() {
        #expect(
            CheckoutWarning.text(account: account, activeLogin: nil, accountCount: 2)
                == "O gh não está logado. Rode gh auth login antes de colar o comando.")
    }
}
