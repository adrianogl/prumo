import SwiftUI
import PRumoKit

struct SettingsView: View {
    let model: AppModel
    @AppStorage(AppConstants.refreshIntervalKey) private var interval = AppConstants.defaultRefreshInterval
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?
    @State private var selection = SettingsTab.account

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private var height: CGFloat {
        switch selection {
        case .general: SettingsMetrics.generalHeight
        case .notifications: NotificationsSettingsMetrics.height
        case .filters: FiltersSettingsMetrics.height
        case .claude: ClaudeSettingsMetrics.height
        case .integrations: IntegrationsSettingsMetrics.height
        case .about: SettingsMetrics.aboutHeight
        default: SettingsMetrics.height
        }
    }

    private var pullRequestRepositories: Set<String> {
        guard let snapshot = model.snapshot else { return [] }
        return Set((snapshot.mine + snapshot.toReview).map(\.repository))
    }

    var body: some View {
        TabView(selection: $selection) {
            Tab(SettingsText.account, systemImage: SettingsSymbol.account, value: SettingsTab.account) { account }
            Tab(SettingsText.general, systemImage: SettingsSymbol.general, value: SettingsTab.general) { general }
            Tab(NotificationsSettingsText.tab, systemImage: NotificationsSettingsSymbol.tab, value: SettingsTab.notifications) {
                NotificationsSettingsView(store: model.preferences)
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
            Tab(SettingsText.about, systemImage: SettingsSymbol.about, value: SettingsTab.about) { about }
        }
        .frame(width: SettingsMetrics.width, height: height)
    }

    private var account: some View {
        Form {
            LabeledContent(SettingsText.login, value: model.login.map { "@\($0)" } ?? SettingsText.notConnected)
            LabeledContent(SettingsText.origin, value: originText)
            Button(SettingsText.disconnect, role: .destructive) {
                model.signOut()
            }
            .disabled(model.needsOnboarding)
        }
        .formStyle(.grouped)
    }

    private var originText: String {
        switch model.origin {
        case .ghCLI: SettingsText.originGh
        case .pasted: SettingsText.originPasted
        case nil: "—"
        }
    }

    private var general: some View {
        Form {
            Picker(SettingsText.interval, selection: $interval) {
                ForEach(AppConstants.refreshIntervalOptions, id: \.seconds) { option in
                    Text(option.label).tag(option.seconds)
                }
            }
            Picker(SettingsText.rowStyle, selection: rowStyle) {
                Text(SettingsText.rowStyleDetailed).tag(RowStyle.detailed)
                Text(SettingsText.rowStyleCompact).tag(RowStyle.compact)
            }
            HotKeyRecorder(model: model)
            Toggle(SettingsText.launchAtLogin, isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { applyLaunchAtLogin() }
            if let launchError {
                Text(launchError).font(.system(size: 12)).foregroundStyle(.red)
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
