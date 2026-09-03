import SwiftUI

/// Drives the enter/exit animation of the overlay.
final class OverlayVisibility: ObservableObject {
    @Published var shown = false
}

/// Wraps `MediaView` (AppKit) for SwiftUI so the enter/exit transforms can be
/// expressed declaratively.
private struct MediaRepresentable: NSViewRepresentable {
    let asset: MediaAsset
    let url: URL
    let targetSize: NSSize
    let playOnce: Bool
    let onComplete: () -> Void

    func makeNSView(context: Context) -> MediaView {
        MediaView(asset: asset, url: url, targetSize: targetSize, playOnce: playOnce, onComplete: onComplete)
    }
    func updateNSView(_ nsView: MediaView, context: Context) {}
}

struct OverlayContentView: View {
    let asset: MediaAsset
    let url: URL
    let targetSize: NSSize
    let playOnce: Bool
    let onComplete: () -> Void
    let onTap: () -> Void
    @ObservedObject var vis: OverlayVisibility

    // fade: 300ms ease-in ; scale 60% → 100%: 500ms ease-out-back
    private let fade: Animation = .easeIn(duration: 0.3)
    private let pop: Animation = .timingCurve(0.34, 1.56, 0.64, 1, duration: 0.5)

    var body: some View {
        ZStack {
            Color.clear
            MediaRepresentable(asset: asset, url: url, targetSize: targetSize,
                               playOnce: playOnce, onComplete: onComplete)
                .fixedSize()
                .scaleEffect(vis.shown ? 1 : 0.6, anchor: .center)
                .animation(pop, value: vis.shown)
                .opacity(vis.shown ? 1 : 0)
                .animation(fade, value: vis.shown)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}
