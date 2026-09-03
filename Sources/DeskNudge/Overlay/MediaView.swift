import AppKit
import Lottie

/// Renders a single media asset (static image, animated GIF, or Lottie JSON)
/// scaled to fit within `maxSize` on its longest edge. The view pins itself to
/// an exact size via constraints so containers lay out predictably.
final class MediaView: NSView {

    private let maxSize: CGFloat
    private var contentView: NSView?
    private var sizeConstraints: [NSLayoutConstraint] = []
    private var intrinsic: NSSize = NSSize(width: 320, height: 320)

    init(asset: MediaAsset, url: URL, maxSize: CGFloat) {
        self.maxSize = maxSize
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        build(asset: asset, url: url)
        applySizeConstraints()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize { intrinsic }

    private func applySizeConstraints() {
        NSLayoutConstraint.deactivate(sizeConstraints)
        sizeConstraints = [
            widthAnchor.constraint(equalToConstant: intrinsic.width),
            heightAnchor.constraint(equalToConstant: intrinsic.height),
        ]
        NSLayoutConstraint.activate(sizeConstraints)
    }

    private func build(asset: MediaAsset, url: URL) {
        switch asset.kind {
        case .lottie:
            let animView = LottieAnimationView(filePath: url.path)
            animView.loopMode = .loop
            animView.contentMode = .scaleAspectFit
            animView.play()
            let natural = animView.animation?.size ?? NSSize(width: 320, height: 320)
            intrinsic = fit(natural)
            embed(animView)

        case .gif, .image:
            guard let image = NSImage(contentsOf: url) else {
                let fallback = NSTextField(labelWithString: "이미지를 불러올 수 없습니다")
                intrinsic = NSSize(width: 240, height: 40)
                embed(fallback)
                return
            }
            let iv = NSImageView()
            iv.image = image
            iv.imageScaling = .scaleProportionallyUpOrDown
            iv.animates = true            // animates multi-frame (GIF) representations
            let natural = (image.size.width > 0 && image.size.height > 0) ? image.size : NSSize(width: 320, height: 320)
            intrinsic = fit(natural)
            embed(iv)
        }
    }

    private func fit(_ size: NSSize) -> NSSize {
        let w = max(size.width, 1), h = max(size.height, 1)
        let scale = min(maxSize / w, maxSize / h)
        return NSSize(width: (w * scale).rounded(), height: (h * scale).rounded())
    }

    private func embed(_ view: NSView) {
        contentView?.removeFromSuperview()
        view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: leadingAnchor),
            view.trailingAnchor.constraint(equalTo: trailingAnchor),
            view.topAnchor.constraint(equalTo: topAnchor),
            view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        contentView = view
        invalidateIntrinsicContentSize()
    }
}
