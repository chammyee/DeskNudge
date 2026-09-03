import Foundation
import AppKit
import CoreGraphics
import CoreMediaIO
import CoreAudio

/// Best-effort detection of "someone can see me / my screen right now".
///
/// macOS provides no single public API that reports "the screen is being
/// recorded", so we combine the signals that *are* available:
///   • display mirroring / AirPlay (`CGDisplayIsInMirrorSet`)
///   • the current-session "screen is captured" hint
///   • running meeting & recorder apps (configurable bundle-id list)
///   • the camera being active anywhere (covers browser video calls)
///   • the microphone being active anywhere (optional; more false positives)
struct CaptureDetector {

    var meetingBundleIDs: [String]
    var checkScreenShare: Bool
    var checkCamera: Bool
    var checkMic: Bool

    func shouldSuppress() -> Bool {
        if checkScreenShare, isScreenBeingShared() { return true }
        if checkCamera, Self.isCameraActive() { return true }
        if checkMic, Self.isMicActive() { return true }
        return false
    }

    // MARK: Screen

    private func isScreenBeingShared() -> Bool {
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
        for d in displays where CGDisplayIsInMirrorSet(d) != 0 && CGDisplayMirrorsDisplay(d) != 0 {
            return true
        }
        return false
    }

    /// The "screen is captured" key is undocumented but has been stable for
    /// years; treated as a soft signal.
    private func isSessionScreenCaptured() -> Bool {
        guard let dict = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        for key in ["CGSSessionScreenIsCaptured", "kCGSSessionScreenIsCaptured"] {
            if let n = dict[key] as? NSNumber, n.boolValue { return true }
            if let b = dict[key] as? Bool, b { return true }
        }
        return false
    }

    private func isMeetingOrRecorderRunning() -> Bool {
        guard !meetingBundleIDs.isEmpty else { return false }
        let ids = Set(meetingBundleIDs.map { $0.lowercased() })
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular,
                  let bid = app.bundleIdentifier?.lowercased() else { continue }
            if ids.contains(bid) { return true }
        }
        return false
    }

    // MARK: Camera (CoreMediaIO)

    static func isCameraActive() -> Bool {
        var addr = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(CMIOObjectID(kCMIOObjectSystemObject), &addr, 0, nil, &size) == noErr,
              size > 0 else { return false }
        let n = Int(size) / MemoryLayout<CMIOObjectID>.size
        var devices = [CMIOObjectID](repeating: 0, count: n)
        guard CMIOObjectGetPropertyData(CMIOObjectID(kCMIOObjectSystemObject), &addr, 0, nil, size, &size, &devices) == noErr
        else { return false }

        for device in devices {
            var runAddr = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
            var running: UInt32 = 0
            var s = UInt32(MemoryLayout<UInt32>.size)
            if CMIOObjectGetPropertyData(device, &runAddr, 0, nil, s, &s, &running) == noErr, running != 0 {
                return true
            }
        }
        return false
    }

    // MARK: Microphone (CoreAudio)

    static func isMicActive() -> Bool {
        var devicesAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &devicesAddr, 0, nil, &size) == noErr,
              size > 0 else { return false }
        let n = Int(size) / MemoryLayout<AudioObjectID>.size
        var devices = [AudioObjectID](repeating: 0, count: n)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &devicesAddr, 0, nil, &size, &devices) == noErr
        else { return false }

        for device in devices {
            // Only consider devices that have input channels.
            var streamAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain)
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(device, &streamAddr, 0, nil, &streamSize) == noErr,
                  streamSize > 0 else { continue }

            var runningAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain)
            var running: UInt32 = 0
            var rs = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(device, &runningAddr, 0, nil, &rs, &running) == noErr, running != 0 {
                return true
            }
        }
        return false
    }
}
