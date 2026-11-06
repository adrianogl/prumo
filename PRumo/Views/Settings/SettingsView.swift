import SwiftUI
import PRumoKit

struct SettingsView: View {
    let model: AppModel
    @AppStorage(AppConstants.refreshIntervalKey) private var interval = AppConstants.defaultRefreshInterval
    @AppStorage(AppConstants.openWindowAtLaunchKey) private var openWindowAtLaunch = false
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?
    @State private var selection = SettingsTab.accounts

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: AppConstants.shortVersionInfoKey) as? String ?? ""
    }

    private var height: CGFloat {
        switch selection {
        case .accounts: AccountsSettingsMetrics.height
        case .general: SettingsMetrics.generalHeight
        case .notifications: NotificationsSettingsMetrics.height
        case .comments: CommentsSettingsMetrics.height
        case .filters: FiltersSettingsMetrics.height
        case .claude: ClaudeSettingsMetrics.height
        case .integrations: IntegrationsSettingsMetrics.height
        case .updates: UpdatesSettingsMetrics.height
        case .about: SettingsMetrics.aboutHeight
        }
    }

    private var updatesSymbol: String {
        model.updates.available == nil ? UpdatesSettingsSymbol.tab : UpdatesSettingsSymbol.tabWithUpdate
    }

    private var pullRequestRepositories: Set<String> {
        guard let snapshot = model.snapshot else { return [] }
        return Set((snapshot.mine + snapshot.toReview).map(\.repositoryKey))
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab(AccountsSettingsText.tab, systemImage: AccountsSettingsSymbol.tab, value: SettingsTab.accounts) {
                AccountsSettingsView(model: model)
            }
            Tab(SettingsText.general, systemImage: SettingsSymbol.general, value: SettingsTab.general) { general }
            Tab(NotificationsSettingsText.tab, systemImage: NotificationsSettingsSymbol.tab, value: SettingsTab.notifications) {
                NotificationsSettingsView(
                    store: model.preferences,
                    showsGitLabNote: model.accounts.list.accounts.contains { $0.provider == .gitlab },
                    permission: model.notificationPermission,
                    sendTest: model.sendTestNotification)
            }
            Tab(CommentsSettingsText.tab, systemImage: CommentsSettingsSymbol.tab, value: SettingsTab.comments) {
                CommentsSettingsView(store: model.organization)
            }
            Tab(FiltersSettingsText.tab, systemImage: FiltersSettingsSymbol.tab, value: SettingsTab.filters) {
                FiltersSettingsView(store: model.organization)
            }
            Tab(ClaudeSettingsText.tab, systemImage: ClaudeSymbol.tab, value: SettingsTab.claude) {
                ClaudeSettingsView(store: model.claude, relevant: pullRequestRepositories)
            }
            Tab(IntegrationsSettingsText.tab, systemImage: IntegrationsSettingsSymbol.tab, value: SettingsTab.integrations) {
                IntegrationsSettingsView(store: model.integrations)
            }
            Tab(UpdatesSettingsText.tab, systemImage: updatesSymbol, value: SettingsTab.updates) {
                UpdatesSettingsView(store: model.updates)
            }
            .badge(model.updates.available == nil ? nil : Text(UpdatesSettingsText.badge))
            Tab(SettingsText.about, systemImage: SettingsSymbol.about, value: SettingsTab.about) { about }
        }
        .frame(width: SettingsMetrics.width, height: height)
    }

    private var general: some View {
        Form {
            Picker(SettingsText.interval, selection: $interval) {
                ForEach(AppConstants.refreshIntervalOptions, id: \.seconds) { option in
                    Text(option.label).tag(option.seconds)
                }
            }
            Picker(SettingsText.stuckCIThreshold, selection: stuckCIThreshold) {
                ForEach(AppConstants.stuckCIThresholdOptions, id: \.seconds) { option in
                    Text(option.label).tag(option.seconds)
                }
            }
            Picker(SettingsText.rowStyle, selection: rowStyle) {
                Text(SettingsText.rowStyleDetailed).tag(RowStyle.detailed)
                Text(SettingsText.rowStyleCompact).tag(RowStyle.compact)
            }
            HotKeyRecorder(model: model)
            Toggle(SettingsText.openWindowAtLaunch, isOn: $openWindowAtLaunch)
            Toggle(SettingsText.launchAtLogin, isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { applyLaunchAtLogin() }
            if let launchError {
                Text(launchError).font(.system(size: 12)).foregroundStyle(Color.statusBad)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            launchAtLogin = LaunchAtLogin.isEnabled
            launchError = LaunchAtLogin.approvalMessage(enabled: launchAtLogin)
        }
    }

    private var rowStyle: Binding<RowStyle> {
        Binding(
            get: { model.organization.settings.rowStyle },
            set: { model.organization.settings.rowStyle = $0 })
    }

    private var stuckCIThreshold: Binding<TimeInterval> {
        Binding(
            get: { model.organization.settings.stuckCIThreshold },
            set: { model.organization.settings.stuckCIThreshold = $0 })
    }

    private var about: some View {
        VStack(spacing: 6) {
            Image(PopoverSymbol.appLogo)
                .resizable()
                .interpolation(.high)
                .frame(width: SettingsMetrics.aboutLogoSize, height: SettingsMetrics.aboutLogoSize)
            Wordmark(size: 22)
            Text("\(SettingsText.version) \(version)").foregroundStyle(.secondary)
            Text(SettingsText.iconCredit)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Link(SettingsText.license, destination: AppConstants.licenseURL)
                .font(.system(size: 12))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func applyLaunchAtLogin() {
        if launchAtLogin != LaunchAtLogin.isEnabled {
            do {
                try LaunchAtLogin.set(launchAtLogin)
            } catch {
                launchError = error.localizedDescription
                launchAtLogin = LaunchAtLogin.isEnabled
                return
            }
        }
        launchError = LaunchAtLogin.approvalMessage(enabled: launchAtLogin)
    }
}
