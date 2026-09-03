import Foundation
import AppKit
import Combine

/// Owns the settings object, persists it to disk, and manages the media file store.
final class Store: ObservableObject {
    static let shared = Store()

    @Published private(set) var settings: AppSettings

    private var cancellables = Set<AnyCancellable>()
    private var saveWorkItem: DispatchWorkItem?

    let supportDirectory: URL
    let mediaDirectory: URL
    private let settingsFile: URL

    private init() {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DeskNudge", isDirectory: true)
        supportDirectory = base
        mediaDirectory = base.appendingPathComponent("Media", isDirectory: true)
        settingsFile = base.appendingPathComponent("settings.json")

        try? fm.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)

        var needsInitialSave = false
        if let data = try? Data(contentsOf: settingsFile),
           let loaded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = loaded
        } else {
            settings = AppSettings.makeDefault()
            needsInitialSave = true
        }

        observe()
        if needsInitialSave { saveNow() }
    }

    private func observe() {
        cancellables.removeAll()
        settings.objectWillChange
            .sink { [weak self] _ in self?.scheduleSave() }
            .store(in: &cancellables)
    }

    private func scheduleSave() {
        saveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.saveNow() }
        saveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
        // Let observers (scheduler, menu) react on the next runloop tick.
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    func saveNow() {
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try enc.encode(settings)
            try data.write(to: settingsFile, options: .atomic)
        } catch {
            NSLog("DeskNudge: failed to save settings: \(error)")
        }
    }

    /// Mutate settings in place and trigger a save.
    func update(_ mutate: (AppSettings) -> Void) {
        mutate(settings)
        settings.objectWillChange.send()
    }

    func replaceSettings(_ new: AppSettings) {
        settings = new
        observe()
        saveNow()
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }

    // MARK: Media

    /// Copies a picked file into the media store and returns the asset descriptor.
    func importMedia(from url: URL) throws -> MediaAsset {
        let fm = FileManager.default
        let ext = url.pathExtension.isEmpty ? "dat" : url.pathExtension.lowercased()
        let fileName = UUID().uuidString + "." + ext
        let dest = mediaDirectory.appendingPathComponent(fileName)
        try fm.copyItem(at: url, to: dest)
        return MediaAsset(fileName: fileName,
                          originalName: url.lastPathComponent,
                          kind: MediaKind.infer(from: url))
    }

    func mediaURL(for asset: MediaAsset) -> URL {
        mediaDirectory.appendingPathComponent(asset.fileName)
    }

    func deleteMediaFile(for asset: MediaAsset) {
        try? FileManager.default.removeItem(at: mediaURL(for: asset))
    }

    func deleteMediaFiles(for item: ReminderItem) {
        for asset in item.media { deleteMediaFile(for: asset) }
    }
}

extension Notification.Name {
    static let settingsChanged = Notification.Name("DeskNudge.settingsChanged")
    static let previewItem = Notification.Name("DeskNudge.previewItem")
}
