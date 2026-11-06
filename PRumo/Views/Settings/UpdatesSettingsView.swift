import SwiftUI
import PRumoKit

struct UpdatesSettingsView: View {
    @Bindable var store: UpdateStore

    var body: some View {
        Form {
            Section {
                Text("\(UpdatesSettingsText.installedPrefix) \(store.installed?.description ?? UpdatesSettingsText.unknownVersion)")
                status
                if let release = store.available {
                    available(release)
                }
                HStack {
                    Button(UpdatesSettingsText.checkNow) { store.checkNow() }
                        .disabled(store.status == .checking || store.installing)
                    Spacer()
                    if let lastCheck = store.lastCheck {
                        Text("\(UpdatesSettingsText.lastCheckPrefix) \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
                            .font(.system(size: UpdatesSettingsMetrics.noteSize))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                VStack(alignment: .leading, spacing: 2) {
                    Toggle(UpdatesSettingsText.autoCheck, isOn: $store.autoCheck)
                    Text(UpdatesSettingsText.autoCheckNote)
                        .font(.system(size: UpdatesSettingsMetrics.noteSize))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .alert(
            UpdatesSettingsText.installFailedTitle,
            isPresented: Binding(
                get: { store.installError != nil },
                set: { if !$0 { store.installError = nil } }),
            presenting: store.installError
        ) { _ in
            Button(UpdatesSettingsText.openRelease) { store.openReleasePage() }
        } message: { error in
            Text(error.message)
        }
    }

    @ViewBuilder
    private var status: some View {
        switch store.status {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: UpdatesSettingsMetrics.rowSpacing) {
                ProgressView().controlSize(.small)
                Text(UpdatesSettingsText.checking)
            }
        case .upToDate:
            Label(UpdatesSettingsText.upToDate, systemImage: UpdatesSettingsSymbol.upToDate)
        case .available(let release):
            Label("\(UpdatesSettingsText.availablePrefix) \(release.version.description)", systemImage: UpdatesSettingsSymbol.available)
                .foregroundStyle(Color.prumoCaramel)
        case .failed:
            Label(UpdatesSettingsText.failed, systemImage: UpdatesSettingsSymbol.failed)
                .foregroundStyle(.secondary)
        }
    }

    private func available(_ release: ReleaseInfo) -> some View {
        VStack(alignment: .leading, spacing: UpdatesSettingsMetrics.rowSpacing) {
            if !release.notes.isEmpty {
                ScrollView {
                    Text(release.notes)
                        .font(.system(size: UpdatesSettingsMetrics.noteSize))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: UpdatesSettingsMetrics.notesHeight)
            }
            if !release.isInstallable {
                Text(UpdatesSettingsText.notInstallable)
                    .font(.system(size: UpdatesSettingsMetrics.noteSize))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: UpdatesSettingsMetrics.rowSpacing) {
                if release.isInstallable {
                    Button(UpdatesSettingsText.install) { store.install() }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.prumoCaramel)
                        .disabled(store.installing)
                    if store.installing {
                        ProgressView().controlSize(.small)
                        Text(UpdatesSettingsText.installing)
                            .foregroundStyle(.secondary)
                    }
                }
                Button(UpdatesSettingsText.viewRelease) { store.openReleasePage() }
            }
        }
    }
}
