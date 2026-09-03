import Foundation

/// A time-of-day range, optionally restricted to certain weekdays.
struct TimeWindow: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    /// Minutes from midnight (0...1439).
    var startMinute: Int = 9 * 60
    /// Minutes from midnight (0...1439). If <= startMinute the window is treated as empty.
    var endMinute: Int = 18 * 60
    /// 1 = Sunday ... 7 = Saturday (matches `Calendar` weekday component).
    var weekdays: Set<Int> = [2, 3, 4, 5, 6]

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let comps = calendar.dateComponents([.hour, .minute, .weekday], from: date)
        guard let h = comps.hour, let m = comps.minute, let wd = comps.weekday else { return false }
        guard weekdays.contains(wd) else { return false }
        let minuteOfDay = h * 60 + m
        return minuteOfDay >= startMinute && minuteOfDay < endMinute
    }

    static func label(forMinute minute: Int) -> String {
        String(format: "%02d:%02d", minute / 60, minute % 60)
    }
}

enum TriggerMode: String, Codable, CaseIterable, Identifiable {
    /// Fires on a fixed cadence aligned to each active window's start (e.g. clock-in every 10 min from 08:30).
    case fixedIntervalInWindows
    /// Fires at a random interval between min and max, only while inside an active window.
    case randomInterval

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fixedIntervalInWindows: return "고정 간격 (시간대 내 반복)"
        case .randomInterval: return "랜덤 간격"
        }
    }
}

enum OverlayPosition: String, Codable, CaseIterable, Identifiable {
    case center, topLeft, topRight, bottomLeft, bottomRight
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .center: return "화면 중앙"
        case .topLeft: return "좌측 상단"
        case .topRight: return "우측 상단"
        case .bottomLeft: return "좌측 하단"
        case .bottomRight: return "우측 하단"
        }
    }
}

enum MediaKind: String, Codable {
    case image      // png/jpg/heic
    case gif        // animated gif
    case lottie     // .json / .lottie

    static func infer(from url: URL) -> MediaKind {
        switch url.pathExtension.lowercased() {
        case "gif": return .gif
        case "json", "lottie": return .lottie
        default: return .image
        }
    }

    var isAnimated: Bool { self != .image }
}

enum DismissMode: String, Codable, CaseIterable, Identifiable {
    case untilClick   // 클릭 시 닫힘
    case timed        // 노출 시간 설정
    case playOnce     // 한 번 재생 (애니메이션만)

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .untilClick: return "클릭 시 닫힘"
        case .timed: return "노출 시간 설정"
        case .playOnce: return "한 번 재생 (애니메이션만)"
        }
    }
}

/// A media file stored in the app's Application Support directory.
struct MediaAsset: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var fileName: String          // stored relative to the Media directory
    var originalName: String
    var kind: MediaKind
}

struct ReminderItem: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String = "새 항목"
    var enabled: Bool = true

    var media: [MediaAsset] = []

    var triggerMode: TriggerMode = .randomInterval

    /// Windows during which this item is allowed to fire. Empty = all day, every day.
    var activeWindows: [TimeWindow] = []

    /// For `.fixedIntervalInWindows`.
    var intervalMinutes: Int = 10

    /// For `.randomInterval` (minutes).
    var minIntervalMinutes: Int = 30
    var maxIntervalMinutes: Int = 60

    /// How the overlay goes away.
    var dismissMode: DismissMode = .timed

    /// Seconds the overlay stays on screen when `dismissMode == .timed`.
    var displayDuration: Double = 8

    var position: OverlayPosition = .center

    /// When true, `position` is ignored and the overlay appears at a random spot
    /// within the central ~60% of the screen.
    var randomizePosition: Bool = true

    /// Longest edge of the overlay in points.
    var maxSize: CGFloat = 320

    func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        guard enabled else { return false }
        if activeWindows.isEmpty { return true }
        return activeWindows.contains { $0.contains(date, calendar: calendar) }
    }

    // Tolerant decoding: missing keys fall back to defaults so older/newer
    // settings files keep loading as the schema evolves.
    init() {}

    enum CodingKeys: String, CodingKey {
        case id, name, enabled, media, triggerMode, activeWindows
        case intervalMinutes, minIntervalMinutes, maxIntervalMinutes
        case dismissMode, displayDuration, position, randomizePosition, maxSize
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        var d = ReminderItem()
        d.id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? d.id
        d.name = try c.decodeIfPresent(String.self, forKey: .name) ?? d.name
        d.enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? d.enabled
        d.media = try c.decodeIfPresent([MediaAsset].self, forKey: .media) ?? d.media
        d.triggerMode = try c.decodeIfPresent(TriggerMode.self, forKey: .triggerMode) ?? d.triggerMode
        d.activeWindows = try c.decodeIfPresent([TimeWindow].self, forKey: .activeWindows) ?? d.activeWindows
        d.intervalMinutes = try c.decodeIfPresent(Int.self, forKey: .intervalMinutes) ?? d.intervalMinutes
        d.minIntervalMinutes = try c.decodeIfPresent(Int.self, forKey: .minIntervalMinutes) ?? d.minIntervalMinutes
        d.maxIntervalMinutes = try c.decodeIfPresent(Int.self, forKey: .maxIntervalMinutes) ?? d.maxIntervalMinutes
        d.displayDuration = try c.decodeIfPresent(Double.self, forKey: .displayDuration) ?? d.displayDuration
        if let mode = try c.decodeIfPresent(DismissMode.self, forKey: .dismissMode) {
            d.dismissMode = mode
        } else {
            d.dismissMode = d.displayDuration > 0 ? .timed : .untilClick
        }
        d.position = try c.decodeIfPresent(OverlayPosition.self, forKey: .position) ?? d.position
        d.randomizePosition = try c.decodeIfPresent(Bool.self, forKey: .randomizePosition) ?? d.randomizePosition
        d.maxSize = try c.decodeIfPresent(CGFloat.self, forKey: .maxSize) ?? d.maxSize
        self = d
    }
}
