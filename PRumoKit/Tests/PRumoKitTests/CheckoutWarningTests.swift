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

    private let gitlabAccount = Account(
        id: "g", provider: .gitlab, host: "gitlab.acme.com", login: "Adriano", origin: .pasted)

    @Test func gitlabWarningWhenGlabNotLogged() {
        #expect(
            CheckoutWarning.text(account: gitlabAccount, activeLogin: nil, accountCount: 2)
                == "O glab não está logado em gitlab.acme.com. Rode glab auth login --hostname gitlab.acme.com antes de colar o comando.")
    }

    @Test func gitlabWarningWhenOtherLogin() {
        #expect(
            CheckoutWarning.text(account: gitlabAccount, activeLogin: "outra", accountCount: 2)
                == "O glab está logado em gitlab.acme.com como @outra. Rode glab auth login --hostname gitlab.acme.com com o token de @Adriano antes de colar o comando.")
    }

    @Test func noGitlabWarningWhenSameLogin() {
        #expect(CheckoutWarning.text(account: gitlabAccount, activeLogin: "adriano", accountCount: 2) == nil)
    }
}
