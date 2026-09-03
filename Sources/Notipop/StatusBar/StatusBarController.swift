import AppKit

/// The menu bar icon and its dropdown menu.
final class StatusBarController: NSObject, NSMenuDelegate {

    private let statusItem: NSStatusItem
    private var store: Store { .shared }
    private var settings: AppSettings { store.settings }

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        NotificationCenter.default.addObserver(self, selector: #selector(refreshIcon),
                                               name: .settingsChanged, object: nil)
        refreshIcon()
    }

    @objc private func refreshIcon() {
        statusItem.isVisible = settings.showMenuBarIcon
        guard let button = statusItem.button else { return }
        let active = settings.globallyEnabled && !settings.isSnoozed
        button.image = AppAsset.menuBarImage(paused: !active)
        button.appearsDisabled = !active
    }

    /// Snooze options shared by the menu bar and the Settings window.
    static let snoozeOptions: [(label: String, minutes: Int)] = [
        ("30분", 30), ("1시간", 60), ("2시간", 120), ("4시간", 240),
    ]

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let master = NSMenuItem(title: "알림 켜기", action: #selector(toggleMaster), keyEquivalent: "")
        master.target = self
        master.state = settings.globallyEnabled ? .on : .off
        menu.addItem(master)

        if settings.isSnoozed, let until = settings.snoozedUntil {
            let s = NSMenuItem(title: "일시정지 해제 (\(Self.timeFmt.string(from: until))까지)",
                               action: #selector(clearSnooze), keyEquivalent: "")
            s.target = self
            menu.addItem(s)
        } else {
            let snooze = NSMenuItem(title: "일시정지", action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for opt in Self.snoozeOptions {
                let mi = NSMenuItem(title: opt.label, action: #selector(snoozeFor(_:)), keyEquivalent: "")
                mi.target = self
                mi.representedObject = opt.minutes
                sub.addItem(mi)
            }
            snooze.submenu = sub
            menu.addItem(snooze)
        }

        menu.addItem(.separator())

        if settings.items.isEmpty {
            let empty = NSMenuItem(title: "항목 없음 — 설정에서 추가하세요", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for (idx, item) in settings.items.enumerated() {
                let mi = NSMenuItem(title: item.name, action: #selector(toggleItem(_:)), keyEquivalent: "")
                mi.target = self
                mi.state = item.enabled ? .on : .off
                mi.representedObject = idx
                menu.addItem(mi)
            }
        }

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "설정…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quit = NSMenuItem(title: "Notipop 종료", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    @objc private func toggleMaster() {
        settings.globallyEnabled.toggle()
    }

    @objc private func toggleItem(_ sender: NSMenuItem) {
        guard let idx = sender.representedObject as? Int, settings.items.indices.contains(idx) else { return }
        settings.items[idx].enabled.toggle()
    }

    @objc private func snoozeFor(_ sender: NSMenuItem) {
        guard let minutes = sender.representedObject as? Int else { return }
        settings.snoozedUntil = Date().addingTimeInterval(Double(minutes) * 60)
    }

    @objc private func clearSnooze() {
        settings.snoozedUntil = nil
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func quit() {
        Store.shared.saveNow()
        NSApp.terminate(nil)
    }

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}
