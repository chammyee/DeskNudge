import AppKit
import Lottie

/// Renders a single media asset (static image, animated GIF, or Lottie JSON)
/// scaled to fit within `maxSize` on its longest edge. The view pins itself to
/// an exact size via constraints so containers lay out predictably.
///
/// When `playOnce` is true the animation runs a single time and `onComplete`
/// fires when it finishes (static images fall back to a short fixed delay).
final class MediaView: NSView {

    private let maxSize: CGFloat
    private let playOnce: Bool
    private let onComplete: (() -> Void)?

    private var contentView: NSView?
    private var sizeConstraints: [NSLayoutConstraint] = []
    private var intrinsic: NSSize = NSSize(width: 320, height: 320)
    private var completionWork: DispatchWorkItem?

    /// Fallback on-screen time for a still image in `.playOnce` mode.
    static let stillImagePlayOnceDuration: TimeInterval = 3

    init(asset: MediaAsset,
         url: URL,
         maxSize: CGFloat,
         playOnce: Bool = false,
         onComplete: (() -> Void)? = nil) {
        self.maxSize = maxSize
        self.playOnce = playOnce
        self.onComplete = onComplete
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        build(asset: asset, url: url)
        applySizeConstraints()
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit { completionWork?.cancel() }

    override var intrinsicContentSize: NSSize { intrinsic }

    private func applySizeConstraints() {
        NSLayoutConstraint.deactivate(sizeConstraints)
        sizeConstraints = [
            widthAnchor.constraint(equalToConstant: intrinsic.width),
            heightAnchor.constraint(equalToConstant: intrinsic.height),
        ]
        NSLayoutConstraint.activate(sizeConstraints)
    }

    private func scheduleCompletion(after delay: TimeInterval) {
        guard let onComplete else { return }
        let work = DispatchWorkItem { onComplete() }
        completionWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + max(delay, 0.3), execute: work)
    }

    private func build(asset: MediaAsset, url: URL) {
        switch asset.kind {
        case .lottie:
            let animView = LottieAnimationView(filePath: url.path)
            animView.contentMode = .scaleAspectFit
            let natural = animView.animation?.size ?? NSSize(width: 320, height: 320)
            intrinsic = fit(natural)
            embed(animView)
            if playOnce {
                animView.loopMode = .playOnce
                animView.play { [weak self] _ in self?.onComplete?() }
            } else {
                animView.loopMode = .loop
                animView.play()
            }

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

            if playOnce {
                if asset.kind == .gif, let total = Self.gifDuration(image), total > 0 {
                    iv.animates = false
                    iv.animates = true
                    scheduleCompletion(after: total)
                    // Stop looping once the first pass is done.
                    let stop = DispatchWorkItem { [weak iv] in iv?.animates = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + total, execute: stop)
                } else {
                    scheduleCompletion(after: Self.stillImagePlayOnceDuration)
                }
            }
        }
    }

    /// The on-screen size the overlay will use, without building the view.
    static func fittedSize(asset: MediaAsset, url: URL, maxSize: CGFloat) -> NSSize {
        let natural: NSSize
        switch asset.kind {
        case .lottie:
            natural = LottieAnimation.filepath(url.path)?.size ?? NSSize(width: 320, height: 320)
        case .image, .gif:
            natural = NSImage(contentsOf: url).map { $0.size } ?? NSSize(width: 320, height: 320)
        }
        let w = max(natural.width, 1), h = max(natural.height, 1)
        let scale = min(maxSize / w, maxSize / h)
        return NSSize(width: (w * scale).rounded(), height: (h * scale).rounded())
    }

    /// Total duration of one loop of an animated GIF, in seconds.
    static func gifDuration(_ image: NSImage) -> TimeInterval? {
        guard let rep = image.representations.compactMap({ $0 as? NSBitmapImageRep }).first,
              let frameCount = rep.value(forProperty: .frameCount) as? Int, frameCount > 1
        else { return nil }
        var total: TimeInterval = 0
        for i in 0..<frameCount {
            rep.setProperty(.currentFrame, withValue: i)
            let d = (rep.value(forProperty: .currentFrameDuration) as? TimeInterval) ?? 0.1
            total += d > 0 ? d : 0.1
        }
        rep.setProperty(.currentFrame, withValue: 0)
        return total
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
