import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool {
        let status = SMAppService.mainApp.status
        return status == .enabled || status == .requiresApproval
    }

    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    static func approvalMessage(enabled: Bool) -> String? {
        enabled && needsApproval ? AppConstants.launchApprovalMessage : nil
    }

    static func set(_ enabled: Bool) throws {
        if enabled {
            guard !isEnabled else { return }
            try SMAppService.mainApp.register()
        } else {
            guard SMAppService.mainApp.status != .notRegistered else { return }
            try SMAppService.mainApp.unregister()
        }
    }
}
