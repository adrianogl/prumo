import SwiftUI
import PRumoKit

struct SettingsView: View {
    let model: AppModel
    @AppStorage(AppConstants.refreshIntervalKey) private var interval = AppConstants.defaultRefreshInterval
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        TabView {
            Tab(SettingsText.account, systemImage: "person.crop.circle") { account }
            Tab(SettingsText.general, systemImage: "gearshape") { general }
            Tab(SettingsText.about, systemImage: "info.circle") { about }
        }
        .frame(width: 420, height: 220)
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
            Toggle(SettingsText.launchAtLogin, isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { applyLaunchAtLogin() }
            if let launchError {
                Text(launchError).font(.system(size: 12)).foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
    }

    private var about: some View {
        VStack(spacing: 6) {
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
        guard launchAtLogin != LaunchAtLogin.isEnabled else { return }
        do {
            try LaunchAtLogin.set(launchAtLogin)
            launchError = LaunchAtLogin.needsApproval ? LaunchAtLogin.approvalMessage : nil
        } catch {
            launchError = error.localizedDescription
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }
}
