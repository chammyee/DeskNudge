import AppKit

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
