import SwiftUI
import AppKit
import Lottie
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var selection: SelectionID? = .general

    enum SelectionID: Hashable { case general, item(UUID) }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    Label("일반", systemImage: "gearshape")
                        .tag(SelectionID.general)
                }
                Section("알림 항목") {
                    ForEach(settings.items) { item in
                        Label {
                            Text(item.name)
                                .foregroundStyle(item.enabled ? .primary : .secondary)
                        } icon: {
                            Image(systemName: item.enabled ? "bell.fill" : "bell.slash")
                        }
                        .tag(SelectionID.item(item.id))
                    }
                    .onDelete { idx in
                        for i in idx { Store.shared.deleteMediaFiles(for: settings.items[i]) }
                        settings.items.remove(atOffsets: idx)
                        settings.objectWillChange.send()
                    }
                }
            }
            .frame(minWidth: 200)
            .safeAreaInset(edge: .bottom) {
                Button {
                    let new = ReminderItem()
                    settings.items.append(new)
                    settings.objectWillChange.send()
                    selection = .item(new.id)
                } label: {
                    Label("항목 추가", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderless)
                .padding(8)
            }
        } detail: {
            switch selection {
            case .general, .none:
                GeneralSettingsView(settings: settings)
            case .item(let id):
                if let idx = settings.items.firstIndex(where: { $0.id == id }) {
                    ItemSettingsView(settings: settings, index: idx, onDelete: {
                        if let i = settings.items.firstIndex(where: { $0.id == id }) {
                            Store.shared.deleteMediaFiles(for: settings.items[i])
                            settings.items.remove(at: i)
                            settings.objectWillChange.send()
                        }
                        selection = .general
                    })
                    .id(id)
                } else {
                    Text("항목을 선택하세요").foregroundStyle(.secondary)
                }
            }
        }
        .frame(minWidth: 720, minHeight: 520)
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var newBundleID = ""

    var body: some View {
        Form {
            Section("동작") {
                Toggle("알림 전체 켜기", isOn: $settings.globallyEnabled)
                Toggle("로그인 시 자동 실행", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { want in
                        let ok = LoginItem.setEnabled(want)
                        settings.launchAtLogin = ok ? want : LoginItem.isEnabled
                        settings.objectWillChange.send()
                    }))
                if LoginItem.requiresUserApproval {
                    Text("시스템 설정 > 일반 > 로그인 항목에서 DeskNudge를 허용해 주세요.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }

            Section("화면 공유·녹화 감지") {
                Toggle("화면 공유/녹화가 감지되면 알림 숨기기", isOn: $settings.suppressDuringScreenShare)
                Text("화면 미러링·AirPlay와 아래 목록의 앱 실행을 감지합니다. 브라우저 안의 웹 회의(Google Meet 등)는 감지되지 않을 수 있습니다.")
                    .font(.callout).foregroundStyle(.secondary)

                ForEach(Array(settings.meetingAppBundleIDs.enumerated()), id: \.offset) { i, bid in
                    let app = InstalledApp.info(bundleID: bid)
                    HStack(spacing: 12) {
                        Image(nsImage: app.icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 64, height: 64)
                            .opacity(app.installed ? 1 : 0.5)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.installed ? app.name : bid)
                                .fontWeight(app.installed ? .medium : .regular)
                            Text(app.installed ? bid : "설치되어 있지 않음")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            settings.meetingAppBundleIDs.remove(at: i)
                            settings.objectWillChange.send()
                        } label: {
                            Image(systemName: "minus.circle").font(.title3)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                }
                HStack {
                    TextField("번들 ID 추가 (예: us.zoom.xos)", text: $newBundleID)
                        .textFieldStyle(.roundedBorder)
                    Button("추가") {
                        let v = newBundleID.trimmingCharacters(in: .whitespaces)
                        guard !v.isEmpty, !settings.meetingAppBundleIDs.contains(v) else { return }
                        settings.meetingAppBundleIDs.append(v)
                        settings.objectWillChange.send()
                        newBundleID = ""
                    }
                }
            }

            Section("일시정지") {
                if settings.isSnoozed, let until = settings.snoozedUntil {
                    HStack {
                        Text("\(until.formatted(date: .omitted, time: .shortened)) 까지 일시정지 중")
                        Spacer()
                        Button("해제") { settings.snoozedUntil = nil; settings.objectWillChange.send() }
                    }
                } else {
                    Text("메뉴바 아이콘에서 일시정지할 수 있습니다.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("일반")
    }
}

// MARK: - Item

private struct ItemSettingsView: View {
    @ObservedObject var settings: AppSettings
    let index: Int
    var onDelete: () -> Void = {}

    private var item: Binding<ReminderItem> {
        Binding(
            get: { settings.items[index] },
            set: { settings.items[index] = $0; settings.objectWillChange.send() }
        )
    }

    var body: some View {
        Form {
            Section {
                TextField("이름", text: item.name)
                Toggle("이 항목 사용", isOn: item.enabled)
            }

            Section("이미지 / 애니메이션") {
                MediaCarousel(item: item)
            }

            Section("표시 시점") {
                Picker("방식", selection: item.triggerMode) {
                    ForEach(TriggerMode.allCases) { Text($0.displayName).tag($0) }
                }
                if item.wrappedValue.triggerMode == .fixedIntervalInWindows {
                    Stepper("반복 간격: \(item.wrappedValue.intervalMinutes)분",
                            value: item.intervalMinutes, in: 1...120)
                    Text("각 시간대 시작 시각부터 이 간격으로 반복됩니다. (예: 출근 08:30부터 10분마다)")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    Stepper("최소 간격: \(item.wrappedValue.minIntervalMinutes)분",
                            value: item.minIntervalMinutes, in: 1...240)
                    Stepper("최대 간격: \(item.wrappedValue.maxIntervalMinutes)분",
                            value: item.maxIntervalMinutes, in: 1...480)
                    Text("이 범위 안에서 무작위 간격으로 등장합니다.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }

            Section("시간대 (비우면 매일 24시간)") {
                WindowsEditor(item: item)
            }

            Section("표시 방식") {
                Toggle("랜덤 위치 (화면 중앙 60% 범위 안에서 무작위)", isOn: item.randomizePosition)
                Picker("고정 위치", selection: item.position) {
                    ForEach(OverlayPosition.allCases) { Text($0.displayName).tag($0) }
                }
                .disabled(item.wrappedValue.randomizePosition)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("크기(최대 한 변)")
                        Slider(value: item.maxSize, in: 120...640, step: 10)
                        Text("\(Int(item.wrappedValue.maxSize))")
                            .monospacedDigit().frame(width: 40, alignment: .trailing)
                    }
                    SizePreview(item: item.wrappedValue)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Picker("표시 시간", selection: item.dismissMode) {
                        ForEach(DismissMode.allCases) { Text($0.displayName).tag($0) }
                    }

                    if item.wrappedValue.dismissMode == .timed {
                        HStack(spacing: 8) {
                            Text("노출 시간")
                            TextField("", value: item.displayDuration, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 56)
                                .multilineTextAlignment(.trailing)
                            Text("초")
                            Stepper("", value: item.displayDuration, in: 1...600, step: 1)
                                .labelsHidden()
                        }
                    }

                    if item.wrappedValue.dismissMode == .playOnce {
                        Text("애니메이션(GIF·Lottie)은 1회 재생 후 사라집니다. 정지 이미지는 \(Int(MediaView.stillImagePlayOnceDuration))초간 표시됩니다.")
                            .font(.callout).foregroundStyle(.secondary)
                    }

                    Text("어떤 모드든 클릭하면 즉시 닫힙니다.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    NotificationCenter.default.post(name: .previewItem, object: settings.items[index])
                } label: {
                    Label("미리보기", systemImage: "eye")
                }
                .disabled(settings.items[index].media.isEmpty)
            }

            Section {
                Button(role: .destructive, action: onDelete) {
                    Label("이 항목 삭제", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(settings.items[index].name)
    }
}

private struct MediaCarousel: View {
    @Binding var item: ReminderItem
    private let thumb: CGFloat = 132

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(alignment: .center, spacing: 12) {
                ForEach(item.media) { asset in
                    ThumbCell(asset: asset, size: thumb) {
                        Store.shared.deleteMediaFile(for: asset)
                        item.media.removeAll { $0.id == asset.id }
                    }
                }
                AddCell(size: thumb) { pick() }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
        }
    }

    private func pick() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        var types: [UTType] = [.png, .jpeg, .gif, .heic, .tiff, .bmp, .json]
        if let lottie = UTType(filenameExtension: "lottie") { types.append(lottie) }
        panel.allowedContentTypes = types
        if panel.runModal() == .OK {
            for url in panel.urls {
                if let asset = try? Store.shared.importMedia(from: url) {
                    item.media.append(asset)
                }
            }
        }
    }
}

private struct ThumbCell: View {
    let asset: MediaAsset
    let size: CGFloat
    let onDelete: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MediaThumbnail(asset: asset)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.primary.opacity(0.12))
                )

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.55))
                    .background(Circle().fill(.black.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .padding(5)
        }
        .help(asset.originalName)   // 이름은 호버 시 툴팁으로만
    }
}

private struct AddCell: View {
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("이미지 / GIF / Lottie JSON")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: size * 1.25, height: size)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(Color.primary.opacity(0.25))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct MediaThumbnail: View {
    let asset: MediaAsset

    var body: some View {
        let url = Store.shared.mediaURL(for: asset)
        Group {
            if asset.kind == .lottie {
                LottieThumbRepresentable(url: url)
            } else if let img = NSImage(contentsOf: url) {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.medium)
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(Color.primary.opacity(0.06))
                    .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
            }
        }
    }
}

private struct LottieThumbRepresentable: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> LottieAnimationView {
        let v = LottieAnimationView(filePath: url.path)
        v.loopMode = .loop
        v.contentMode = .scaleAspectFill
        v.play()
        return v
    }

    func updateNSView(_ nsView: LottieAnimationView, context: Context) {}
}

private struct WindowsEditor: View {
    @Binding var item: ReminderItem
    private let dayNames = ["일", "월", "화", "수", "목", "금", "토"]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(item.activeWindows.enumerated()), id: \.element.id) { i, _ in
                let w = Binding(
                    get: { item.activeWindows[i] },
                    set: { item.activeWindows[i] = $0 }
                )
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        MinutePicker(title: "시작", minute: Binding(get: { w.wrappedValue.startMinute }, set: { var v = w.wrappedValue; v.startMinute = $0; w.wrappedValue = v }))
                        Text("–")
                        MinutePicker(title: "종료", minute: Binding(get: { w.wrappedValue.endMinute }, set: { var v = w.wrappedValue; v.endMinute = $0; w.wrappedValue = v }))
                        Spacer()
                        Button(role: .destructive) {
                            item.activeWindows.remove(at: i)
                        } label: { Image(systemName: "minus.circle") }
                        .buttonStyle(.borderless)
                    }
                    HStack(spacing: 4) {
                        ForEach(1...7, id: \.self) { d in
                            let on = w.wrappedValue.weekdays.contains(d)
                            Button(dayNames[d - 1]) {
                                var v = w.wrappedValue
                                if on { v.weekdays.remove(d) } else { v.weekdays.insert(d) }
                                w.wrappedValue = v
                            }
                            .buttonStyle(.bordered)
                            .tint(on ? .accentColor : .gray)
                        }
                    }
                }
                Divider()
            }
            Button {
                item.activeWindows.append(TimeWindow())
            } label: { Label("시간대 추가", systemImage: "plus") }
        }
    }
}

// MARK: - Size preview

/// Shows the overlay drawn to scale inside a miniature screen so the user can
/// judge how big it will actually appear.
private struct SizePreview: View {
    let item: ReminderItem
    private let previewWidth: CGFloat = 380

    var body: some View {
        let screen = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame.size
            ?? CGSize(width: 1512, height: 900)
        let scale = previewWidth / screen.width
        let previewHeight = screen.height * scale
        let box = item.maxSize * scale
        let firstAsset = item.media.first

        VStack(alignment: .leading, spacing: 4) {
            Text("실제 화면 대비 크기 미리보기")
                .font(.caption).foregroundStyle(.secondary)
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .underPageBackgroundColor))
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.secondary.opacity(0.4))

                if item.randomizePosition {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.accentColor.opacity(0.5),
                                      style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .frame(width: previewWidth * 0.6, height: previewHeight * 0.6)
                }

                Group {
                    if let asset = firstAsset {
                        MediaPreviewRepresentable(asset: asset, maxSize: box)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.25))
                            .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                            .frame(width: box, height: box)
                    }
                }
                .shadow(radius: 3, y: 1)
            }
            .frame(width: previewWidth, height: previewHeight)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

private struct MediaPreviewRepresentable: NSViewRepresentable {
    let asset: MediaAsset
    let maxSize: CGFloat

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.subviews.forEach { $0.removeFromSuperview() }
        let url = Store.shared.mediaURL(for: asset)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let media = MediaView(asset: asset, url: url, maxSize: max(8, maxSize))
        nsView.addSubview(media)
        NSLayoutConstraint.activate([
            media.centerXAnchor.constraint(equalTo: nsView.centerXAnchor),
            media.centerYAnchor.constraint(equalTo: nsView.centerYAnchor),
        ])
    }
}

private struct MinutePicker: View {
    let title: String
    @Binding var minute: Int

    var body: some View {
        HStack(spacing: 4) {
            Text(title).foregroundStyle(.secondary)
            Picker("", selection: Binding(get: { minute / 60 }, set: { minute = $0 * 60 + (minute % 60) })) {
                ForEach(0...23, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }.labelsHidden().frame(width: 60)
            Text(":")
            Picker("", selection: Binding(get: { minute % 60 }, set: { minute = (minute / 60) * 60 + $0 })) {
                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }.labelsHidden().frame(width: 60)
        }
    }
}
