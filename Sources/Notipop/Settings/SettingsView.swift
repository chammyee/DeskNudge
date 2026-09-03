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
            .frame(minWidth: 210)
            .navigationTitle("Notipop 설정")
            .safeAreaInset(edge: .bottom) {
                Button {
                    let new = ReminderItem()
                    settings.items.append(new)
                    settings.objectWillChange.send()
                    selection = .item(new.id)
                } label: {
                    Label("알림 추가하기", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .tint(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 22)
            }
        } detail: {
            switch selection {
            case .general, .none:
                GeneralSettingsView(settings: settings)
            case .item(let id):
                if settings.items.firstIndex(where: { $0.id == id }) != nil {
                    ItemSettingsView(settings: settings, itemID: id, onDelete: {
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
        .frame(minWidth: 740, minHeight: 540)
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var newBundleID = ""
    @State private var snoozeChoice = StatusBarController.snoozeOptions.first!.minutes

    private var snoozeLabel: String {
        StatusBarController.snoozeOptions.first { $0.minutes == snoozeChoice }?.label ?? "\(snoozeChoice)분"
    }

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
                    Text("시스템 설정 > 일반 > 로그인 항목에서 Notipop을 허용해 주세요.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                Toggle("메뉴 바에 표시", isOn: $settings.showMenuBarIcon)
                if !settings.showMenuBarIcon {
                    Text("메뉴 바 아이콘을 숨기면 Finder나 Spotlight에서 Notipop을 다시 실행해 설정을 열 수 있습니다.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }

            Section("일시정지") {
                if settings.isSnoozed, let until = settings.snoozedUntil {
                    HStack {
                        Text("\(until.formatted(date: .omitted, time: .shortened))까지 일시정지 중")
                        Spacer()
                        Button("해제") {
                            settings.snoozedUntil = nil
                            settings.objectWillChange.send()
                        }
                    }
                } else {
                    LabeledContent("다음 시간 동안 일시 정지") {
                        Menu(snoozeLabel) {
                            ForEach(StatusBarController.snoozeOptions, id: \.minutes) { opt in
                                Button(opt.label) {
                                    snoozeChoice = opt.minutes
                                    settings.snoozedUntil = Date().addingTimeInterval(Double(opt.minutes) * 60)
                                    settings.objectWillChange.send()
                                }
                            }
                        }
                        .fixedSize()
                    }
                }
            }

            Section("회의·녹화 중 알림 중지") {
                Toggle("카메라가 켜져 있으면 알림 중지", isOn: $settings.suppressWhenCameraActive)
                Toggle("마이크가 켜져 있으면 알림 중지", isOn: $settings.suppressWhenMicActive)
                Toggle("화면 공유, 미러링이 감지되면 알림 중지", isOn: $settings.suppressDuringScreenShare)
                Text("브라우저 영상 통화 포함. 브라우저 안의 웹 회의는 앱으로는 안 잡히지만 대부분 카메라를 켜므로 ‘카메라’ 옵션으로 커버됩니다. 화면만 공유하고 카메라를 끈 경우는 감지되지 않을 수 있습니다.")
                    .font(.callout).foregroundStyle(.secondary)
            }

            Section("회의·녹화 감지할 앱") {
                HStack {
                    TextField("번들 ID 추가 (예: us.zoom.xos)", text: $newBundleID)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addBundleID)
                    Button("추가하기", action: addBundleID)
                }

                ForEach(Array(settings.meetingAppBundleIDs.enumerated()), id: \.offset) { i, bid in
                    let app = InstalledApp.info(bundleID: bid)
                    HStack(spacing: 12) {
                        Image(nsImage: app.icon)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 64, height: 64)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(app.name).fontWeight(.medium)
                            Text(app.installed ? bid : "\(bid) · 미설치")
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
            }
        }
        .formStyle(.grouped)
    }

    private func addBundleID() {
        let v = newBundleID.trimmingCharacters(in: .whitespaces)
        guard !v.isEmpty, !settings.meetingAppBundleIDs.contains(v) else { return }
        settings.meetingAppBundleIDs.append(v)
        settings.objectWillChange.send()
        newBundleID = ""
    }
}

// MARK: - Item

private struct ItemSettingsView: View {
    @ObservedObject var settings: AppSettings
    let itemID: UUID
    var onDelete: () -> Void = {}

    private var index: Int? { settings.items.firstIndex(where: { $0.id == itemID }) }

    private var item: Binding<ReminderItem> {
        Binding(
            get: { settings.items.first(where: { $0.id == itemID }) ?? ReminderItem() },
            set: { new in
                if let i = index { settings.items[i] = new; settings.objectWillChange.send() }
            }
        )
    }

    var body: some View {
        Form {
            Section {
                TextField("이름", text: item.name)
                Toggle("알림 켜기", isOn: item.enabled)
            }

            Section("이미지 / 애니메이션") {
                MediaCarousel(item: item)
            }

            Section("알림 간격") {
                Picker("방식", selection: item.triggerMode) {
                    ForEach(TriggerMode.allCases) { Text($0.displayName).tag($0) }
                }
                if item.wrappedValue.triggerMode == .fixedIntervalInWindows {
                    Stepper("반복 간격: \(item.wrappedValue.intervalMinutes)분",
                            value: item.intervalMinutes, in: 1...120)
                    Text("각 허용 시간 시작 시각부터 이 간격으로 반복됩니다. (예: 08:30부터 10분마다)")
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

            Section("알림 허용 시간") {
                WindowsEditor(item: item)
            }

            Section("표시 설정") {
                Toggle("위치 고정", isOn: item.fixedPosition)
                Picker("위치", selection: item.position) {
                    ForEach(OverlayPosition.allCases) { Text($0.displayName).tag($0) }
                }
                .disabled(!item.wrappedValue.fixedPosition)
                Text(item.wrappedValue.fixedPosition
                     ? "선택한 위치에 고정으로 표시돼요."
                     : "화면 가운데 근처에 랜덤으로 나타나요.")
                    .font(.callout).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("크기")
                        Slider(value: item.sizeScale, in: 0.3...3.0)
                        Text("\(Int((item.wrappedValue.sizeScale * 100).rounded()))%")
                            .monospacedDigit().frame(width: 48, alignment: .trailing)
                    }
                    SizePreview(item: item.wrappedValue)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Picker("알림 스타일", selection: item.dismissMode) {
                        ForEach(DismissMode.allCases) { Text($0.displayName).tag($0) }
                    }

                    if item.wrappedValue.dismissMode == .timed {
                        HStack(spacing: 8) {
                            Text("표시 시간")
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
                HStack {
                    Button {
                        if let i = index {
                            NotificationCenter.default.post(name: .previewItem, object: settings.items[i])
                        }
                    } label: {
                        Label("미리보기", systemImage: "eye")
                    }
                    .disabled(item.wrappedValue.media.isEmpty)

                    Spacer()

                    Button(role: .destructive, action: onDelete) {
                        Text("삭제").frame(minWidth: 64)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct MediaCarousel: View {
    @Binding var item: ReminderItem
    private let thumb: CGFloat = 140

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
                .background(Color.primary.opacity(0.05))
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
                Text("이미지 / GIF /\nLottie JSON")
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(width: size, height: size)
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
                    .aspectRatio(contentMode: .fit)
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
        v.contentMode = .scaleAspectFit
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
            if item.activeWindows.isEmpty {
                Text("비어 있으면 매일 24시간 알림이 허용됩니다.")
                    .font(.callout).foregroundStyle(.secondary)
            }
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
                            DayToggle(label: dayNames[d - 1], on: on) {
                                var v = w.wrappedValue
                                if on { v.weekdays.remove(d) } else { v.weekdays.insert(d) }
                                w.wrappedValue = v
                            }
                        }
                    }
                }
                Divider()
            }
            Button {
                item.activeWindows.append(TimeWindow())   // 기본: 매일 00:00–24:00
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
        let previewScale = previewWidth / screen.width
        let previewHeight = screen.height * previewScale

        let firstAsset = item.media.first
        let natural: CGSize = firstAsset.map {
            MediaView.naturalSize(asset: $0, url: Store.shared.mediaURL(for: $0))
        } ?? CGSize(width: 240, height: 240)
        let boxW = natural.width * item.sizeScale * previewScale
        let boxH = natural.height * item.sizeScale * previewScale

        VStack(alignment: .leading, spacing: 4) {
            Text("실제 화면 대비 크기 미리보기")
                .font(.caption).foregroundStyle(.secondary)
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .underPageBackgroundColor))
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.secondary.opacity(0.4))

                if !item.fixedPosition {
                    let f = OverlayController.randomAreaFraction
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(nsColor: .textBackgroundColor))
                        .frame(width: previewWidth * f, height: previewHeight * f)
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.accentColor.opacity(0.5),
                                      style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .frame(width: previewWidth * f, height: previewHeight * f)
                }

                Group {
                    if let asset = firstAsset {
                        MediaPreviewRepresentable(asset: asset,
                                                  targetSize: NSSize(width: max(boxW, 6), height: max(boxH, 6)))
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(0.25))
                            .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                            .frame(width: max(boxW, 6), height: max(boxH, 6))
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
    let targetSize: NSSize

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.subviews.forEach { $0.removeFromSuperview() }
        let url = Store.shared.mediaURL(for: asset)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let media = MediaView(asset: asset, url: url, targetSize: targetSize)
        nsView.addSubview(media)
        NSLayoutConstraint.activate([
            media.centerXAnchor.constraint(equalTo: nsView.centerXAnchor),
            media.centerYAnchor.constraint(equalTo: nsView.centerYAnchor),
        ])
    }
}

private struct DayToggle: View {
    let label: String
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.callout)
                .frame(width: 28, height: 26)
                .foregroundStyle(on ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .background(on ? Color(red: 0x20 / 255, green: 0x20 / 255, blue: 0x20 / 255)
                        : Color(nsColor: .controlColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.15)))
    }
}

private struct MinutePicker: View {
    let title: String
    @Binding var minute: Int

    var body: some View {
        HStack(spacing: 4) {
            Text(title).foregroundStyle(.secondary)
            Picker("", selection: Binding(get: { min(minute / 60, 24) }, set: { minute = $0 * 60 + (minute % 60) })) {
                ForEach(0...24, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }.labelsHidden().frame(width: 60)
            Text(":")
            Picker("", selection: Binding(get: { minute % 60 }, set: { minute = (minute / 60) * 60 + $0 })) {
                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }.labelsHidden().frame(width: 60)
        }
    }
}
