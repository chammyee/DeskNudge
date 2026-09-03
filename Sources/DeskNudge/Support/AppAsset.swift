import AppKit
import UniformTypeIdentifiers

/// Central place for app artwork. Custom vector files in `Resources/` win;
/// otherwise we fall back to SF Symbols so the app always has an icon.
///
/// Menu-bar files (optional), added to `Sources/DeskNudge/Resources/`:
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

/// Resolves an installed app's real icon + display name from its bundle id.
/// Apps that aren't installed fall back to the generic application icon.
enum InstalledApp {

    struct Info {
        var name: String
        var icon: NSImage
        var installed: Bool
    }

    private static var cache: [String: Info] = [:]

    static func info(bundleID: String) -> Info {
        if let hit = cache[bundleID] { return hit }
        let ws = NSWorkspace.shared
        let result: Info
        if let url = ws.urlForApplication(withBundleIdentifier: bundleID) {
            let icon = ws.icon(forFile: url.path)
            icon.size = NSSize(width: 64, height: 64)
            var name = FileManager.default.displayName(atPath: url.path)
            if name.hasSuffix(".app") { name = String(name.dropLast(4)) }
            result = Info(name: name, icon: icon, installed: true)
        } else {
            let generic = ws.icon(for: .application)
            generic.size = NSSize(width: 64, height: 64)
            result = Info(name: bundleID, icon: generic, installed: false)
        }
        cache[bundleID] = result
        return result
    }

    static func clearCache() { cache.removeAll() }
}
