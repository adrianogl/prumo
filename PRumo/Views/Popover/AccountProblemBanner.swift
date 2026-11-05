import SwiftUI
import PRumoKit

struct AccountProblemBanner: View {
    let account: Account
    let status: AccountStatus
    let onSettings: () -> Void

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = PopoverText.clockFormat
        return formatter
    }()

    private var name: String {
        account.nickname.isEmpty ? "@\(account.login)" : account.nickname
    }

    var body: some View {
        switch status.state {
        case nil, .ok?:
            EmptyView()
        case let .offline(lastSuccess)?:
            WarningBanner {
                HStack(spacing: 4) {
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        let since = status.lastSuccess ?? lastSuccess
                        Text(PopoverText.accountOffline(
                            name: name, host: account.host,
                            age: since.map { RelativeAge.string(from: $0, now: context.date) }))
                    }
                    Button(PopoverText.accountSettings, action: onSettings).buttonStyle(.link)
                }
            }
        case .unauthorized?:
            WarningBanner {
                HStack(spacing: 4) {
                    Text(PopoverText.accountInvalidToken(name: name, host: account.host))
                    Button(PopoverText.accountReconnect, action: onSettings).buttonStyle(.link)
                }
            }
        case let .rateLimited(resetAt)?:
            WarningBanner {
                Text(PopoverText.accountRateLimited(
                    name: name, host: account.host, resetAt: resetAt.map(Self.clock.string(from:))))
            }
        case .unexpectedResponse?:
            WarningBanner { Text(PopoverText.accountUnexpectedResponse(name: name, host: account.host)) }
        }
    }
}
