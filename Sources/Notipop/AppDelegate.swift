import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // menu-bar only, no Dock icon

        _ = Store.shared                        // load settings

        // Keep the login-item registration in sync with the saved preference.
        let want = Store.shared.settings.launchAtLogin
        if want != LoginItem.isEnabled {
            LoginItem.setEnabled(want)
        }

        statusBar = StatusBarController()
        Scheduler.shared.start()

        if Store.shared.settings.items.isEmpty {
            SettingsWindowController.shared.show()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowController.shared.show()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        Store.shared.saveNow()
    }
}
