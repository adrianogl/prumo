import Testing

@testable import PRumoKit

@Suite struct NotificationSubtitlesTests {
    @Test func subtitlesEmptyWithOneAccount() {
        let accounts = [Account(id: "a1", login: "adriano", origin: .pasted)]
        #expect(NotificationSubtitles.make(accounts: accounts).isEmpty)
    }

    @Test func subtitlesUseLabel() {
        let accounts = [
            Account(id: "a1", login: "adriano", origin: .pasted),
            Account(id: "a2", login: "adriano-globex", origin: .pasted),
        ]
        #expect(NotificationSubtitles.make(accounts: accounts) == ["a1": "adriano", "a2": "adriano-globex"])
    }
}
