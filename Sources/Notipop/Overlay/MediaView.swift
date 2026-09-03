import AppKit
import Lottie

/// Renders a single media asset (static image, animated GIF, or Lottie JSON) at
/// an exact `targetSize` (caller computes it from the media's natural size and
/// the item's size scale). The view pins itself to that size via constraints.
///
/// When `playOnce` is true the animation runs a single time and `onComplete`
/// fires when it finishes (static images fall back to a short fixed delay).
final class MediaView: NSView {

    private let targetSize: NSSize
    private let playOnce: Bool
    private let onComplete: (() -> Void)?

    private var contentView: NSView?
    private var completionWork: DispatchWorkItem?

    /// Fallback on-screen time for a still image in `.playOnce` mode.
    static let stillImagePlayOnceDuration: TimeInterval = 3

    init(asset: MediaAsset,
         url: URL,
         targetSize: NSSize,
         playOnce: Bool = false,
         onComplete: (() -> Void)? = nil) {
        self.targetSize = NSSize(width: max(targetSize.width.rounded(), 8),
                                 height: max(targetSize.height.rounded(), 8))
        self.playOnce = playOnce
        self.onComplete = onComplete
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        build(asset: asset, url: url)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: self.targetSize.width),
            heightAnchor.constraint(equalToConstant: self.targetSize.height),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit { completionWork?.cancel() }

    override var intrinsicContentSize: NSSize { targetSize }

    // MARK: Sizing helpers

    /// Natural (100%) size of the media, without building the view.
    static func naturalSize(asset: MediaAsset, url: URL) -> NSSize {
        let fallback = NSSize(width: 320, height: 320)
        let s: NSSize
        switch asset.kind {
        case .lottie:
            s = LottieAnimation.filepath(url.path)?.size ?? fallback
        case .image, .gif:
            s = NSImage(contentsOf: url).map { $0.size } ?? fallback
        }
        return (s.width > 0 && s.height > 0) ? s : fallback
    }

    // MARK: Build

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
                embed(NSTextField(labelWithString: "이미지를 불러올 수 없습니다"))
                return
            }
            let iv = NSImageView()
            iv.image = image
            iv.imageScaling = .scaleProportionallyUpOrDown
            iv.animates = true            // animates multi-frame (GIF) representations
            embed(iv)

            if playOnce {
                if asset.kind == .gif, let total = Self.gifDuration(image), total > 0 {
                    scheduleCompletion(after: total)
                    let stop = DispatchWorkItem { [weak iv] in iv?.animates = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + total, execute: stop)
                } else {
                    scheduleCompletion(after: Self.stillImagePlayOnceDuration)
                }
            }
        }
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
    }
}
