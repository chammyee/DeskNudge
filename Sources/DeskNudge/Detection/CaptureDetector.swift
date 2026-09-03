import Foundation
import AppKit
import CoreGraphics

/// Best-effort detection of "someone can see my screen right now".
///
/// macOS provides no single public API that reports "the screen is being recorded".
/// We combine the signals that *are* available:
///   • display mirroring / AirPlay (`CGDisplayIsInMirrorSet`)
///   • the current-session "screen is captured" hint
///   • running meeting & recorder apps (configurable bundle-id list)
///
/// Web-based calls (Google Meet in a browser, web Zoom) generally cannot be detected.
struct CaptureDetector {

    var meetingBundleIDs: [String]

    func isScreenBeingShared() -> Bool {
        if isDisplayMirrored() { return true }
        if isSessionScreenCaptured() { return true }
        if isMeetingOrRecorderRunning() { return true }
        return false
    }

    private func isDisplayMirrored() -> Bool {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        guard count > 0 else { return false }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &displays, &count)
        for d in displays {
            if CGDisplayIsInMirrorSet(d) != 0 && CGDisplayMirrorsDisplay(d) != 0 {
                return true
            }
        }
        return false
    }

    /// Reads the login-session dictionary. The "screen is captured" key is
    /// undocumented but has been stable for years; treated as a soft signal.
    private func isSessionScreenCaptured() -> Bool {
        guard let dict = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        for key in ["CGSSessionScreenIsCaptured", "kCGSSessionScreenIsCaptured"] {
            if let v = dict[key] as? Bool, v { return true }
            if let n = dict[key] as? NSNumber, n.boolValue { return true }
        }
        return false
    }

    private func isMeetingOrRecorderRunning() -> Bool {
        guard !meetingBundleIDs.isEmpty else { return false }
        let running = NSWorkspace.shared.runningApplications
        let ids = Set(meetingBundleIDs.map { $0.lowercased() })
        for app in running {
            guard app.activationPolicy == .regular else { continue }
            if let bid = app.bundleIdentifier?.lowercased(), ids.contains(bid) {
                return true
            }
        }
        return false
    }
}
