import AppKit

/// Shows a borderless, non-activating panel that floats above every app and on
/// every Space (including full-screen apps). Click anywhere or wait for the
/// auto-dismiss timer to close it.
final class OverlayController {

    static let shared = OverlayController()
    private init() {}

    private var panel: NSPanel?
    private var dismissTimer: Timer?

    var isShowing: Bool { panel != nil }

    func show(item: ReminderItem) {
        guard !isShowing else { return }
        guard let asset = pickAsset(for: item) else { return }
        let url = Store.shared.mediaURL(for: asset)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let media = MediaView(asset: asset, url: url, maxSize: item.maxSize)
        media.translatesAutoresizingMaskIntoConstraints = false

        let container = ClickThroughDismissView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 18
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.92).cgColor
        container.layer?.shadowColor = NSColor.black.cgColor
        container.layer?.shadowOpacity = 0.28
        container.layer?.shadowRadius = 24
        container.layer?.shadowOffset = CGSize(width: 0, height: -6)

        let label = NSTextField(labelWithString: item.name)
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.alignment = .center
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(media)
        container.addSubview(label)
        NSLayoutConstraint.activate([
            media.topAnchor.constraint(equalTo: container.topAnchor, constant: 18),
            media.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            media.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 18),
            media.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -18),
            label.topAnchor.constraint(equalTo: media.bottomAnchor, constant: 10),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -16),
        ])

        let panel = NSPanel(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.worksWhenModal = true
        panel.ignoresMouseEvents = false
        panel.contentView = container
        container.onDismiss = { [weak self] in self?.dismiss() }

        panel.layoutIfNeeded()
        let fitting = container.fittingSize
        let size = NSSize(width: max(fitting.width, 160), height: max(fitting.height, 120))
        let frame = frameRect(size: size, item: item)
        panel.setFrame(frame, display: true)

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            panel.animator().alphaValue = 1
        }

        self.panel = panel
        NSLog("DeskNudge: overlay shown for '\(item.name)' asset=\(asset.kind.rawValue) frame=\(NSStringFromRect(frame))")
        #if DEBUG
        DebugLog.write("shown \(item.name) \(asset.kind.rawValue) size=\(size)")
        #endif

        if item.displayDuration > 0 {
            dismissTimer = Timer.scheduledTimer(withTimeInterval: item.displayDuration,
                                                repeats: false) { [weak self] _ in
                self?.dismiss()
            }
        }
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        guard let panel else { return }
        self.panel = nil
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            panel.animator().alphaValue = 0
        } completionHandler: {
            panel.orderOut(nil)
        }
    }

    private func pickAsset(for item: ReminderItem) -> MediaAsset? {
        let existing = item.media.filter {
            FileManager.default.fileExists(atPath: Store.shared.mediaURL(for: $0).path)
        }
        return existing.randomElement()
    }

    private func frameRect(size: NSSize, item: ReminderItem) -> NSRect {
        let screen = screenUnderCursor()
        let vf = screen.visibleFrame
        let margin: CGFloat = 32
        var origin: NSPoint

        if item.randomizePosition {
            // Random spot within the central 60% of the screen so the overlay
            // stays near the middle and never hugs an edge.
            let box = NSRect(x: vf.minX + vf.width * 0.2,
                             y: vf.minY + vf.height * 0.2,
                             width: vf.width * 0.6,
                             height: vf.height * 0.6)
            let xLo = box.minX
            let xHi = max(box.minX, box.maxX - size.width)
            let yLo = box.minY
            let yHi = max(box.minY, box.maxY - size.height)
            origin = NSPoint(x: CGFloat.random(in: xLo...xHi),
                             y: CGFloat.random(in: yLo...yHi))
        } else {
            switch item.position {
            case .center:
                origin = NSPoint(x: vf.midX - size.width / 2, y: vf.midY - size.height / 2)
            case .topLeft:
                origin = NSPoint(x: vf.minX + margin, y: vf.maxY - size.height - margin)
            case .topRight:
                origin = NSPoint(x: vf.maxX - size.width - margin, y: vf.maxY - size.height - margin)
            case .bottomLeft:
                origin = NSPoint(x: vf.minX + margin, y: vf.minY + margin)
            case .bottomRight:
                origin = NSPoint(x: vf.maxX - size.width - margin, y: vf.minY + margin)
            }
        }

        // Keep fully on-screen.
        origin.x = min(max(origin.x, vf.minX + 8), vf.maxX - size.width - 8)
        origin.y = min(max(origin.y, vf.minY + 8), vf.maxY - size.height - 8)
        return NSRect(origin: origin, size: size)
    }

    /// The overlay should appear on whichever display the user is currently looking at.
    private func screenUnderCursor() -> NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first!
    }
}

/// A view that dismisses the overlay on any mouse-down.
private final class ClickThroughDismissView: NSView {
    var onDismiss: (() -> Void)?
    override func mouseDown(with event: NSEvent) { onDismiss?() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
