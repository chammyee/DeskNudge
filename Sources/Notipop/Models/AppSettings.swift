import Foundation
import Combine

final class AppSettings: ObservableObject, Codable {
    /// Master switch. When false, nothing is shown.
    @Published var globallyEnabled: Bool = true

    /// Suppress overlays while a screen recording / mirroring / known meeting app is detected.
    @Published var suppressDuringScreenShare: Bool = true

    /// Suppress overlays while the camera is active anywhere (covers browser video calls).
    @Published var suppressWhenCameraActive: Bool = true

    /// Suppress overlays while the microphone is active anywhere (more false positives).
    @Published var suppressWhenMicActive: Bool = false

    /// Bundle identifiers that, when running, count as "screen sharing / recording in progress".
    @Published var meetingAppBundleIDs: [String] = [
        "us.zoom.xos",                 // Zoom
        "com.microsoft.teams2",        // Teams (new)
        "com.microsoft.teams",         // Teams (classic)
        "com.hnc.Discord",             // Discord
        "com.tinyspeck.slackmacgap",   // Slack
        "com.obsproject.obs-studio",   // OBS
        "com.apple.QuickTimePlayerX",  // QuickTime screen recording
        "com.loom.desktop",            // Loom
        "com.cisco.webexmeetingsapp",  // Webex
        "com.google.meet",             // Google Meet (standalone PWA)
    ]

    /// Overlays paused until this date (snooze). nil = not snoozed.
    @Published var snoozedUntil: Date? = nil

    @Published var launchAtLogin: Bool = false

    @Published var items: [ReminderItem] = []

    // MARK: Codable

    enum CodingKeys: String, CodingKey {
        case globallyEnabled, suppressDuringScreenShare, meetingAppBundleIDs
        case suppressWhenCameraActive, suppressWhenMicActive
        case snoozedUntil, launchAtLogin, items
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        globallyEnabled = try c.decodeIfPresent(Bool.self, forKey: .globallyEnabled) ?? true
        suppressDuringScreenShare = try c.decodeIfPresent(Bool.self, forKey: .suppressDuringScreenShare) ?? true
        suppressWhenCameraActive = try c.decodeIfPresent(Bool.self, forKey: .suppressWhenCameraActive) ?? true
        suppressWhenMicActive = try c.decodeIfPresent(Bool.self, forKey: .suppressWhenMicActive) ?? false
        if let ids = try c.decodeIfPresent([String].self, forKey: .meetingAppBundleIDs) {
            meetingAppBundleIDs = ids
        }
        snoozedUntil = try c.decodeIfPresent(Date.self, forKey: .snoozedUntil)
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        items = try c.decodeIfPresent([ReminderItem].self, forKey: .items) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(globallyEnabled, forKey: .globallyEnabled)
        try c.encode(suppressDuringScreenShare, forKey: .suppressDuringScreenShare)
        try c.encode(suppressWhenCameraActive, forKey: .suppressWhenCameraActive)
        try c.encode(suppressWhenMicActive, forKey: .suppressWhenMicActive)
        try c.encode(meetingAppBundleIDs, forKey: .meetingAppBundleIDs)
        try c.encodeIfPresent(snoozedUntil, forKey: .snoozedUntil)
        try c.encode(launchAtLogin, forKey: .launchAtLogin)
        try c.encode(items, forKey: .items)
    }

    var isSnoozed: Bool {
        if let until = snoozedUntil { return until > Date() }
        return false
    }

    // MARK: Defaults

    static func makeDefault() -> AppSettings {
        let s = AppSettings()

        var clockIn = ReminderItem()
        clockIn.name = "출근 찍기"
        clockIn.triggerMode = .fixedIntervalInWindows
        clockIn.intervalMinutes = 10
        clockIn.activeWindows = [TimeWindow(startMinute: 8 * 60 + 30, endMinute: 9 * 60 + 30, weekdays: [2, 3, 4, 5, 6])]
        clockIn.dismissMode = .untilClick
        clockIn.randomizePosition = false
        clockIn.position = .center

        var clockOut = ReminderItem()
        clockOut.name = "퇴근 찍기"
        clockOut.triggerMode = .fixedIntervalInWindows
        clockOut.intervalMinutes = 10
        clockOut.activeWindows = [TimeWindow(startMinute: 18 * 60, endMinute: 19 * 60, weekdays: [2, 3, 4, 5, 6])]
        clockOut.dismissMode = .untilClick
        clockOut.randomizePosition = false
        clockOut.position = .center

        var back = ReminderItem()
        back.name = "허리 펴기"
        back.triggerMode = .randomInterval
        back.minIntervalMinutes = 35
        back.maxIntervalMinutes = 55
        back.activeWindows = [TimeWindow(startMinute: 9 * 60 + 30, endMinute: 18 * 60, weekdays: [2, 3, 4, 5, 6])]
        back.dismissMode = .timed
        back.displayDuration = 8
        back.randomizePosition = true

        var posture = ReminderItem()
        posture.name = "자세 고쳐앉기"
        posture.triggerMode = .randomInterval
        posture.minIntervalMinutes = 40
        posture.maxIntervalMinutes = 70
        posture.activeWindows = [TimeWindow(startMinute: 9 * 60 + 30, endMinute: 18 * 60, weekdays: [2, 3, 4, 5, 6])]
        posture.dismissMode = .timed
        posture.displayDuration = 8
        posture.randomizePosition = true

        var stretch = ReminderItem()
        stretch.name = "목·눈 스트레칭"
        stretch.triggerMode = .randomInterval
        stretch.minIntervalMinutes = 45
        stretch.maxIntervalMinutes = 90
        stretch.activeWindows = [TimeWindow(startMinute: 9 * 60 + 30, endMinute: 18 * 60, weekdays: [2, 3, 4, 5, 6])]
        stretch.dismissMode = .timed
        stretch.displayDuration = 10
        stretch.randomizePosition = true

        s.items = [clockIn, clockOut, back, posture, stretch]
        return s
    }
}
