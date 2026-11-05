import Foundation
import Testing
@testable import PRumoKit

@Suite struct AccountListTests {
    private func account(_ id: String, login: String, nickname: String = "", host: String = "github.com", origin: TokenOrigin = .pasted) -> Account {
        Account(id: id, host: host, login: login, nickname: nickname, origin: origin)
    }

    @Test func accountListRoundTrip() {
        let list = AccountList(accounts: [
            account("a1", login: "adrianogl", nickname: "pessoal", origin: .ghCLI),
            account("a2", login: "adriano-globex", host: "github.globex.com")
        ])
        #expect(AccountList.decode(list.encoded()) == list)
    }

    @Test func unknownProviderDropsOnlyThatAccount() {
        let json = #"{"accounts":[{"id":"a1","provider":"bitbucket","login":"x"},{"id":"a2","provider":"github","login":"adrianogl"}]}"#
        let list = AccountList.decode(Data(json.utf8))
        #expect(list?.accounts.map(\.id) == ["a2"])
    }

    @Test func missingFieldsUseDefaults() {
        let json = #"{"accounts":[{"id":"a1","provider":"github","login":"adrianogl"}]}"#
        let item = AccountList.decode(Data(json.utf8))?.accounts.first
        #expect(item?.host == "github.com")
        #expect(item?.nickname == "")
        #expect(item?.origin == .pasted)
    }

    @Test func decodeNilMeansNoList() {
        #expect(AccountList.decode(nil) == nil)
    }

    @Test func invalidDataMeansNoList() {
        #expect(AccountList.decode(Data("nope".utf8)) == nil)
    }

    @Test func allUnreadableAccountsMeansNoList() {
        let json = #"{"accounts":[{"id":"a1","provider":"bitbucket","login":"x"},{"nope":1}]}"#
        #expect(AccountList.decode(Data(json.utf8)) == nil)
    }

    @Test func savedEmptyListIsValid() {
        #expect(AccountList.decode(Data(#"{"accounts":[]}"#.utf8)) == AccountList())
    }

    @Test func addRejectsSameIdentityIgnoringCase() {
        var list = AccountList()
        #expect(list.add(account("a1", login: "adrianogl")) == true)
        #expect(list.add(account("a2", login: "AdrianoGL", host: "GitHub.com")) == false)
        #expect(list.accounts.count == 1)
    }

    @Test func renameAndUpdateLogin() {
        var list = AccountList(accounts: [account("a1", login: "adrianogl")])
        list.rename(id: "a1", nickname: "pessoal")
        list.updateLogin(id: "a1", login: "adriano-acme")
        #expect(list.account(id: "a1")?.nickname == "pessoal")
        #expect(list.account(id: "a1")?.login == "adriano-acme")
        list.remove(id: "a1")
        #expect(list.accounts.isEmpty)
    }

    @Test func displayNameUsesNickname() {
        #expect(account("a1", login: "adrianogl", nickname: "pessoal").displayName == "pessoal · @adrianogl")
        #expect(account("a1", login: "adrianogl").displayName == "@adrianogl")
    }

    @Test func labelNilWithOneAccount() {
        let one = [account("a1", login: "adrianogl")]
        #expect(AccountLabel.forRow(accountID: "a1", accounts: one) == nil)
        let two = one + [account("a2", login: "adriano-globex")]
        #expect(AccountLabel.forRow(accountID: "zz", accounts: two) == nil)
    }

    @Test func labelOmitsPublicHost() {
        let two = [account("a1", login: "adrianogl"), account("a2", login: "adriano-globex")]
        #expect(AccountLabel.forRow(accountID: "a2", accounts: two)?.text == "adriano-globex")
        #expect(AccountLabel.make(account("a3", login: "adriano", host: "gitlab.empresa.com")).text == "adriano · gitlab.empresa.com")
    }
}
