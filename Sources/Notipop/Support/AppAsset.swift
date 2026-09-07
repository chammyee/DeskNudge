import AppKit

/// Menu-bar icon. A custom template PDF dropped in `seed/`
/// (`MenuBarIcon.pdf` / `MenuBarIconPaused.pdf`, black on transparent, ~18pt)
/// wins; otherwise an SF Symbol is used so the app always has an icon.
enum AppAsset {

    static let menuBarPointSize: CGFloat = 18

    static func menuBarImage(paused: Bool) -> NSImage {
        let name = paused ? "MenuBarIconPaused" : "MenuBarIcon"
        if let url = Bundle.main.url(forResource: name, withExtension: "pdf", subdirectory: "seed"),
           let img = NSImage(contentsOf: url) {
            img.isTemplate = true
            img.size = NSSize(width: menuBarPointSize, height: menuBarPointSize)
            return img
        }
        let symbol = paused ? "bell.slash" : "bell.badge"
        let img = NSImage(systemSymbolName: symbol, accessibilityDescription: "Notipop")
            ?? NSImage(size: NSSize(width: menuBarPointSize, height: menuBarPointSize))
        img.isTemplate = true
        return img
    }
}
