import AppKit
import UniformTypeIdentifiers

/// Central place for app artwork. Custom vector files in `Resources/` win;
/// otherwise we fall back to SF Symbols so the app always has an icon.
///
/// Menu-bar files (optional), added to `Sources/Notipop/Resources/`:
///   • `MenuBarIcon.pdf`        — single-colour (black on transparent), ~18pt square
///   • `MenuBarIconPaused.pdf`  — same, shown while paused / disabled
/// Both are treated as template images (macOS tints them for light/dark).
enum AppAsset {

    static let menuBarPointSize: CGFloat = 18

    static func menuBarImage(paused: Bool) -> NSImage {
        let name = paused ? "MenuBarIconPaused" : "MenuBarIcon"
        if let url = Bundle.module.url(forResource: name, withExtension: "pdf"),
           let img = NSImage(contentsOf: url) {
            img.isTemplate = true
            img.size = NSSize(width: menuBarPointSize, height: menuBarPointSize)
            return img
        }
        // Fallback: SF Symbols.
        let symbol = paused ? "bell.slash" : "bell.badge"
        let img = NSImage(systemSymbolName: symbol, accessibilityDescription: "Notipop")
            ?? NSImage(size: NSSize(width: menuBarPointSize, height: menuBarPointSize))
        img.isTemplate = true
        return img
    }
}

/// Resolves an app's icon + display name from its bundle id.
///
/// Priority: real installed icon → user override PNG in
/// `~/Library/Application Support/Notipop/AppIcons/<bundleid>.png` →
/// a generated letter avatar (coloured tile with the app's initial).
enum InstalledApp {

    struct Info {
        var name: String
        var icon: NSImage
        var installed: Bool
    }

    /// Friendly names for well-known bundle ids that may not be installed.
    static let knownNames: [String: String] = [
        "us.zoom.xos": "Zoom",
        "com.microsoft.teams2": "Microsoft Teams",
        "com.microsoft.teams": "Microsoft Teams",
        "com.hnc.Discord": "Discord",
        "com.tinyspeck.slackmacgap": "Slack",
        "com.obsproject.obs-studio": "OBS Studio",
        "com.apple.QuickTimePlayerX": "QuickTime Player",
        "com.loom.desktop": "Loom",
        "com.cisco.webexmeetingsapp": "Webex",
        "com.google.meet": "Google Meet",
        "com.google.Chrome": "Google Chrome",
        "com.apple.Safari": "Safari",
        "company.thebrowser.Browser": "Arc",
        "com.readdle.smartemail-Mac": "Spark",
    ]

    private static var cache: [String: Info] = [:]

    static func info(bundleID: String) -> Info {
        if let hit = cache[bundleID] { return hit }
        let ws = NSWorkspace.shared
        let friendly = knownNames[bundleID] ?? knownNames[bundleID.lowercased()]
        let result: Info

        if let url = ws.urlForApplication(withBundleIdentifier: bundleID) {
            let icon = ws.icon(forFile: url.path)
            icon.size = NSSize(width: 64, height: 64)
            var name = FileManager.default.displayName(atPath: url.path)
            if name.hasSuffix(".app") { name = String(name.dropLast(4)) }
            result = Info(name: friendly ?? name, icon: icon, installed: true)
        } else if let override = overrideIcon(for: bundleID) {
            result = Info(name: friendly ?? bundleID, icon: override, installed: false)
        } else {
            let name = friendly ?? bundleID
            result = Info(name: name, icon: letterAvatar(for: name, seed: bundleID), installed: false)
        }

        cache[bundleID] = result
        return result
    }

    static func clearCache() { cache.removeAll() }

    private static func overrideIcon(for bundleID: String) -> NSImage? {
        let url = Store.shared.supportDirectory
            .appendingPathComponent("AppIcons", isDirectory: true)
            .appendingPathComponent(bundleID)
            .appendingPathExtension("png")
        guard let img = NSImage(contentsOf: url) else { return nil }
        img.size = NSSize(width: 64, height: 64)
        return img
    }

    private static func letterAvatar(for name: String, seed: String) -> NSImage {
        let side: CGFloat = 64
        let initial = name.first(where: { $0.isLetter || $0.isNumber })
        let letter = initial.map { String($0).uppercased() } ?? "?"

        var hash: UInt64 = 5381
        for b in seed.utf8 { hash = (hash &* 33) ^ UInt64(b) }
        let hue = CGFloat(hash % 360) / 360.0
        let bg = NSColor(hue: hue, saturation: 0.45, brightness: 0.72, alpha: 1)

        let image = NSImage(size: NSSize(width: side, height: side))
        image.lockFocus()
        // Match the visual weight of real macOS app icons: the tile fills ~80%
        // of the canvas (the rest is the padding/shadow region .icns files have).
        let inset = side * 0.10
        let tile = NSRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
        let clip = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.225, yRadius: tile.width * 0.225)
        clip.setClip()
        bg.setFill(); tile.fill()

        let para = NSMutableParagraphStyle(); para.alignment = .center
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: tile.width * 0.55, weight: .semibold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: para,
        ]
        let size = (letter as NSString).size(withAttributes: attrs)
        (letter as NSString).draw(at: NSPoint(x: tile.midX - size.width / 2,
                                              y: tile.midY - size.height / 2),
                                  withAttributes: attrs)
        image.unlockFocus()
        return image
    }
}
