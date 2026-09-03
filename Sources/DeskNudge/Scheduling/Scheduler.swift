import Foundation
import AppKit

/// Drives when each reminder fires. A single low-frequency tick evaluates every
/// item. Because it uses a plain `Timer`, it is naturally suspended while the Mac
/// sleeps and resumes (without a burst of catch-up alerts) on wake.
final class Scheduler {

    static let shared = Scheduler()
    private init() {}

    private var tick: Timer?
    private var nextFire: [UUID: Date] = [:]
    private let calendar = Calendar.current

    private var store: Store { .shared }
    private var settings: AppSettings { store.settings }

    func start() {
        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: .settingsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handlePreview(_:)),
                                               name: .previewItem, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(wake),
            name: NSWorkspace.didWakeNotification, object: nil)

        reload()
        let t = Timer(timeInterval: 20, target: self, selector: #selector(evaluate), userInfo: nil, repeats: true)
        t.tolerance = 5
        RunLoop.main.add(t, forMode: .common)
        tick = t
        evaluate()
    }

    @objc private func wake() {
        // Re-plan everything from "now" so we don't fire for a slot that passed
        // while the machine was asleep.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.reload() }
    }

    @objc private func reload() {
        let now = Date()
        var updated: [UUID: Date] = [:]
        for item in settings.items where item.enabled {
            updated[item.id] = nextFire[item.id] ?? planNextFire(for: item, after: now)
        }
        nextFire = updated
        evaluate()
    }

    @objc private func evaluate() {
        let now = Date()

        guard settings.globallyEnabled, !settings.isSnoozed else { return }
        if OverlayController.shared.isShowing { return }

        if settings.suppressDuringScreenShare {
            let detector = CaptureDetector(meetingBundleIDs: settings.meetingAppBundleIDs)
            if detector.isScreenBeingShared() {
                // Nudge each due item a minute into the future and re-check later.
                for (id, date) in nextFire where date <= now {
                    nextFire[id] = now.addingTimeInterval(60)
                }
                return
            }
        }

        // Fire the earliest due, active item (one at a time).
        let due = settings.items
            .filter { $0.enabled }
            .filter { (nextFire[$0.id] ?? .distantFuture) <= now }
            .filter { $0.isActive(at: now, calendar: calendar) }
            .filter { !$0.media.isEmpty }
            .sorted { (nextFire[$0.id] ?? .distantFuture) < (nextFire[$1.id] ?? .distantFuture) }

        if let item = due.first {
            OverlayController.shared.show(item: item)
            nextFire[item.id] = planNextFire(for: item, after: now)
        }

        // Any due-but-inactive item gets re-planned so it doesn't fire the instant
        // its window opens with a stale timestamp.
        for item in settings.items where item.enabled {
            if let d = nextFire[item.id], d <= now, !item.isActive(at: now, calendar: calendar) {
                nextFire[item.id] = planNextFire(for: item, after: now)
            }
        }
    }

    @objc private func handlePreview(_ note: Notification) {
        guard let item = note.object as? ReminderItem else { return }
        OverlayController.shared.dismiss()
        OverlayController.shared.show(item: item)
    }

    // MARK: Planning

    private func planNextFire(for item: ReminderItem, after now: Date) -> Date {
        switch item.triggerMode {
        case .fixedIntervalInWindows:
            return nextFixedInterval(for: item, after: now) ?? now.addingTimeInterval(3600)
        case .randomInterval:
            return nextRandomInterval(for: item, after: now)
        }
    }

    private func nextRandomInterval(for item: ReminderItem, after now: Date) -> Date {
        let lo = max(1, min(item.minIntervalMinutes, item.maxIntervalMinutes))
        let hi = max(lo, max(item.minIntervalMinutes, item.maxIntervalMinutes))
        let minutes = Int.random(in: lo...hi)
        var candidate = now.addingTimeInterval(Double(minutes) * 60)

        if item.activeWindows.isEmpty { return candidate }
        if item.isActive(at: candidate, calendar: calendar) { return candidate }

        // Otherwise jump to the next window opening plus a little jitter.
        if let opening = nextWindowOpening(for: item, after: now) {
            candidate = opening.addingTimeInterval(Double(Int.random(in: 0...max(1, lo))) * 60)
        } else {
            candidate = now.addingTimeInterval(3600)
        }
        return candidate
    }

    private func nextFixedInterval(for item: ReminderItem, after now: Date) -> Date? {
        let windows = item.activeWindows.isEmpty
            ? [TimeWindow(startMinute: 0, endMinute: 24 * 60, weekdays: [1,2,3,4,5,6,7])]
            : item.activeWindows
        let step = max(1, item.intervalMinutes)

        var best: Date?
        for dayOffset in 0...8 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)) else { continue }
            let wd = calendar.component(.weekday, from: day)
            for w in windows where w.weekdays.contains(wd) && w.endMinute > w.startMinute {
                var m = w.startMinute
                while m < w.endMinute {
                    if let slot = calendar.date(byAdding: .minute, value: m, to: day), slot > now {
                        if best == nil || slot < best! { best = slot }
                        break
                    }
                    m += step
                }
            }
            if best != nil { break }
        }
        return best
    }

    private func nextWindowOpening(for item: ReminderItem, after now: Date) -> Date? {
        guard !item.activeWindows.isEmpty else { return now }
        var best: Date?
        for dayOffset in 0...8 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)) else { continue }
            let wd = calendar.component(.weekday, from: day)
            for w in item.activeWindows where w.weekdays.contains(wd) && w.endMinute > w.startMinute {
                if let open = calendar.date(byAdding: .minute, value: w.startMinute, to: day), open > now {
                    if best == nil || open < best! { best = open }
                }
            }
            if best != nil { break }
        }
        return best
    }
}
