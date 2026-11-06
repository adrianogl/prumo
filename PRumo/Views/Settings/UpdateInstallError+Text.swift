import PRumoKit

extension UpdateInstallError {
    var message: String {
        switch self {
        case .notInstallable: UpdatesSettingsText.failureNotInstallable
        case .notWritable: UpdatesSettingsText.failureNotWritable
        case .downloadFailed: UpdatesSettingsText.failureDownload
        case .checksumMismatch: UpdatesSettingsText.failureChecksum
        case .mountFailed: UpdatesSettingsText.failureMount
        case .copyFailed: UpdatesSettingsText.failureCopy
        case .replaceFailed: UpdatesSettingsText.failureReplace
        case .relaunchFailed: UpdatesSettingsText.failureRelaunch
        }
    }
}
