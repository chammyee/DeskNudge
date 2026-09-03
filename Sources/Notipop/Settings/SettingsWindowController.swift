import AppKit
import SwiftUI

/// Hosts `SettingsView` in a normal window that can be opened from the menu bar.
final class SettingsWindowController {

    static let shared = SettingsWindowController()
    private init() {}

    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let root = SettingsView(settings: Store.shared.settings)
        let hosting = NSHostingController(rootView: root)

        let win = NSWindow(contentViewController: hosting)
        win.title = "Notipop 설정"
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        win.setContentSize(NSSize(width: 820, height: 600))
        win.center()
        win.isReleasedWhenClosed = false
        win.delegate = windowDelegate

        window = win
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private lazy var windowDelegate: WinDelegate = {
        let d = WinDelegate()
        d.onClose = { [weak self] in
            Store.shared.saveNow()
            self?.window = nil
        }
        return d
    }()

    private final class WinDelegate: NSObject, NSWindowDelegate {
        var onClose: (() -> Void)?
        func windowWillClose(_ notification: Notification) { onClose?() }
    }
}
