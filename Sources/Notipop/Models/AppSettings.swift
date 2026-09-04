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

    /// Show the menu-bar icon. When hidden, relaunch the app to reopen Settings.
    @Published var showMenuBarIcon: Bool = true

    @Published var items: [ReminderItem] = []

    // MARK: Codable

    enum CodingKeys: String, CodingKey {
        case globallyEnabled, suppressDuringScreenShare, meetingAppBundleIDs
        case suppressWhenCameraActive, suppressWhenMicActive
        case snoozedUntil, launchAtLogin, showMenuBarIcon, items
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
        showMenuBarIcon = try c.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? true
        items = try c.decodeIfPresent([ReminderItem].self, forKey: .items) ?? []
    }

    // Codable can't be synthesized through @Published, so both halves are manual.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(globallyEnabled, forKey: .globallyEnabled)
        try c.encode(suppressDuringScreenShare, forKey: .suppressDuringScreenShare)
        try c.encode(suppressWhenCameraActive, forKey: .suppressWhenCameraActive)
        try c.encode(suppressWhenMicActive, forKey: .suppressWhenMicActive)
        try c.encode(meetingAppBundleIDs, forKey: .meetingAppBundleIDs)
        try c.encodeIfPresent(snoozedUntil, forKey: .snoozedUntil)
        try c.encode(launchAtLogin, forKey: .launchAtLogin)
        try c.encode(showMenuBarIcon, forKey: .showMenuBarIcon)
        try c.encode(items, forKey: .items)
    }

    var isSnoozed: Bool {
        if let until = snoozedUntil { return until > Date() }
        return false
    }

    // MARK: Defaults

    static func makeDefault() -> AppSettings {
        let s = AppSettings()
        let weekdays: Set<Int> = [2, 3, 4, 5, 6]

        var clock = ReminderItem()
        clock.name = "출퇴근 찍기"
        clock.triggerMode = .fixedIntervalInWindows
        clock.intervalMinutes = 10
        clock.activeWindows = [
            TimeWindow(startMinute: 8 * 60 + 30, endMinute: 9 * 60 + 30, weekdays: weekdays),
            TimeWindow(startMinute: 18 * 60, endMinute: 19 * 60, weekdays: weekdays),
        ]
        clock.dismissMode = .untilClick
        clock.fixedPosition = true
        clock.position = .center

        var posture = ReminderItem()
        posture.name = "자세 고쳐앉기"
        posture.triggerMode = .randomInterval
        posture.minIntervalMinutes = 30
        posture.maxIntervalMinutes = 60
        posture.activeWindows = [TimeWindow(startMinute: 9 * 60 + 30, endMinute: 18 * 60, weekdays: weekdays)]
        posture.dismissMode = .timed
        posture.displayDuration = 8

        s.items = [clock, posture]
        return s
    }
}
