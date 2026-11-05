import SwiftUI
import PRumoKit

struct StatusBanner: View {
    let connection: ConnectionState
    let nextRefresh: Date?
    let onReconnect: () -> Void

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    var body: some View {
        switch connection {
        case .ok:
            EmptyView()
        case let .offline(lastSuccess):
            retryBanner { PopoverText.offline(lastSuccess: lastSuccess.map(Self.clock.string(from:)), retryIn: $0) }
        case let .unexpectedResponse(lastSuccess):
            retryBanner { PopoverText.unexpectedResponse(lastSuccess: lastSuccess.map(Self.clock.string(from:)), retryIn: $0) }
        case .unauthorized:
            banner {
                HStack(spacing: 4) {
                    Text(PopoverText.invalidToken)
                    Button(PopoverText.reconnect, action: onReconnect)
                        .buttonStyle(.link)
                }
            }
        case let .rateLimited(resetAt):
            banner { Text(PopoverText.rateLimited(resetAt: resetAt.map(Self.clock.string(from:)))) }
        }
    }

    private func retryBanner(_ message: @escaping (Int) -> String) -> some View {
        banner {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = max(0, Int((nextRefresh ?? context.date).timeIntervalSince(context.date).rounded(.up)))
                Text(message(remaining))
            }
        }
    }

    private func banner<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
            content()
            Spacer(minLength: 0)
        }
        .font(.system(size: 11.5))
        .foregroundStyle(Color(nsColor: .systemOrange))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .systemOrange).opacity(0.12))
    }
}
