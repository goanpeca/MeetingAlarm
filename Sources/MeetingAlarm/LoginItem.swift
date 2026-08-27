import ServiceManagement

/// Thin wrapper over `SMAppService.mainApp` (macOS 13+) so the app can register itself as a
/// login item — launching automatically after a restart/login. The user also sees and can
/// revoke this under System Settings › General › Login Items.
enum LoginItem {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Register/unregister as a login item. Returns false if the system refused (e.g. an
    /// unsigned/translocated build), so the UI can revert an optimistic toggle.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        let log = Log.make("loginitem")
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            return true
        } catch {
            log
                .error(
                    "launch-at-login toggle failed: \(error.localizedDescription, privacy: .public)"
                )
            return false
        }
    }
}
