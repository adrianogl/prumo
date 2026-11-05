import SwiftUI
import PRumoKit

struct AccountRowView: View {
    let account: Account
    let status: AccountStatus?
    let onRetry: () -> Void
    let onReconnect: () -> Void
    let onRename: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: AccountsSettingsMetrics.rowSpacing) {
            ProviderIcon(kind: account.provider, size: AccountsSettingsMetrics.providerIconSize)
                .frame(width: AccountsSettingsMetrics.providerIconSize + AccountsSettingsMetrics.stateSpacing)
            VStack(alignment: .leading, spacing: AccountsSettingsMetrics.nameSpacing) {
                Text(account.displayName).fontWeight(.semibold)
                Text(AccountsSettingsText.detail(host: account.host, origin: account.origin))
                    .font(.system(size: AccountsSettingsMetrics.detailSize))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            stateLabel
            action
            Menu {
                Button(AccountsSettingsText.reconnect, action: onReconnect)
                Button(AccountsSettingsText.rename, action: onRename)
                Divider()
                Button(AccountsSettingsText.remove, role: .destructive, action: onRemove)
            } label: {
                Image(systemName: AccountsSettingsSymbol.more)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private var stateLabel: some View {
        HStack(spacing: AccountsSettingsMetrics.stateSpacing) {
            Circle()
                .fill(stateColor)
                .frame(width: AccountsSettingsMetrics.stateDotSize, height: AccountsSettingsMetrics.stateDotSize)
            Text(stateText)
        }
        .font(.system(size: AccountsSettingsMetrics.stateSize))
        .foregroundStyle(status?.isProblem == true ? stateColor : .secondary)
    }

    @ViewBuilder
    private var action: some View {
        switch status?.state {
        case .offline:
            Button(AccountsSettingsText.retry, action: onRetry)
        case .unauthorized:
            Button(AccountsSettingsText.reconnect, action: onReconnect)
        default:
            EmptyView()
        }
    }

    private var stateText: String {
        switch status?.state {
        case nil: AccountsSettingsText.connecting
        case .ok: AccountsSettingsText.connected
        case .offline: account.isPublicHost ? AccountsSettingsText.offline : AccountsSettingsText.offlinePrivateHost
        case .unauthorized: AccountsSettingsText.unauthorized
        case .rateLimited(let resetAt?): AccountsSettingsText.rateLimitedUntil(ClockFormat.string(from: resetAt))
        case .rateLimited(nil): AccountsSettingsText.rateLimited
        case .unexpectedResponse: AccountsSettingsText.unexpectedResponse
        }
    }

    private var stateColor: Color {
        switch status?.state {
        case nil: .gray
        case .ok: .green
        case .unauthorized: .red
        case .offline, .rateLimited, .unexpectedResponse: .orange
        }
    }
}
