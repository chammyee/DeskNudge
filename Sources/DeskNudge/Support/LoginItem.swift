import Foundation
import ServiceManagement

/// Wraps `SMAppService.mainApp` so the app can register itself as a login item.
enum LoginItem {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Returns true on success. May throw if the app is not a proper bundle
    /// (e.g. run straight from `swift run`).
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
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
            NSLog("DeskNudge: login item toggle failed: \(error.localizedDescription)")
            return false
        }
    }

    static var requiresUserApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }
}
