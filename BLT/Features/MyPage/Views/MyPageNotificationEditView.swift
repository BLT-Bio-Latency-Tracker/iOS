import SwiftUI
import UIKit
import UserNotifications

struct MyPageNotificationEditView: View {
    @Environment(\.scenePhase) private var scenePhase

    let settings: MyPageNotificationSettings
    let onBack: () -> Void
    let onSave: (MyPageNotificationEditDraft) -> Void

    @State private var draft: MyPageNotificationEditDraft
    @State private var activePicker: NotificationTimePicker?
    @State private var isRequestingNotificationPermission = false
    @State private var showsNotificationSettingsAlert = false
    @State private var notificationPermissionMessage = ""
    @State private var shouldEnableAfterReturningFromSettings = false

    private let designWidth: CGFloat = 375
    private let designHeight: CGFloat = 812

    init(
        settings: MyPageNotificationSettings,
        onBack: @escaping () -> Void,
        onSave: @escaping (MyPageNotificationEditDraft) -> Void
    ) {
        self.settings = settings
        self.onBack = onBack
        self.onSave = onSave
        _draft = State(initialValue: MyPageNotificationEditDraft(settings: settings))
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / designWidth, proxy.size.height / designHeight)
            let contentWidth = min(proxy.size.width - 24, 351 * scale)
            let horizontalInset = max(12, (proxy.size.width - contentWidth) / 2)
            let topPadding = max(8 * scale, 56 * scale - proxy.safeAreaInsets.top)

            ZStack {
                Color.myPageNotificationBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header(scale: scale)
                        .padding(.top, topPadding)
                        .padding(.horizontal, horizontalInset)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20 * scale) {
                            notificationToggleSection(scale: scale)
                            timeSection(scale: scale)
                            channelSection(scale: scale)
                        }
                        .padding(.top, 36 * scale)
                        .padding(.horizontal, horizontalInset)
                        .padding(.bottom, 24 * scale)
                    }

                    saveButton(scale: scale)
                        .padding(.horizontal, horizontalInset)
                        .padding(.bottom, max(32, 32 * scale))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .preferredColorScheme(.dark)
        .sheet(item: $activePicker) { picker in
            pickerSheet(for: picker)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
        .alert("알림 권한이 꺼져 있어요", isPresented: $showsNotificationSettingsAlert) {
            Button("설정으로 이동") {
                shouldEnableAfterReturningFromSettings = true
                openAppSettings()
            }

            Button("취소", role: .cancel) {}
        } message: {
            Text(notificationPermissionMessage)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, shouldEnableAfterReturningFromSettings else { return }

            Task {
                await enableNotificationAfterReturningFromSettings()
            }
        }
    }

    private func header(scale: CGFloat) -> some View {
        ZStack {
            Text("알림 설정")
                .font(.system(size: 16 * scale, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)

            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18 * scale, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32 * scale, height: 32 * scale)
                        .background(Color.myPageNotificationCard)
                        .clipShape(RoundedRectangle(cornerRadius: 10 * scale, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("뒤로가기")

                Spacer()
            }
        }
        .frame(height: 32 * scale)
    }

    private func notificationToggleSection(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 7 * scale) {
            sectionTitle("알림", scale: scale)

            HStack {
                VStack(alignment: .leading, spacing: 4 * scale) {
                    Text("앱 알림")
                        .font(.system(size: 16 * scale, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(notificationToggleDescription)
                        .font(.system(size: 11 * scale, weight: .regular))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer()

                Toggle(
                    "",
                    isOn: Binding(
                        get: { draft.isEnabled },
                        set: { setNotificationEnabled($0) }
                    )
                )
                    .labelsHidden()
                    .tint(Color.myPageNotificationPrimary)
                    .disabled(isRequestingNotificationPermission)
            }
            .padding(.horizontal, 16 * scale)
            .frame(maxWidth: .infinity)
            .frame(height: 64 * scale)
            .background(Color.myPageNotificationCard)
            .clipShape(RoundedRectangle(cornerRadius: 12 * scale, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12 * scale, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
        }
    }

    private func timeSection(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12 * scale) {
            sectionTitle("알림 시간", scale: scale)

            timeButton(
                title: "측정 알림",
                value: draft.measurementTime.map(Self.formattedTime) ?? "시간을 선택해주세요",
                isPlaceholder: draft.measurementTime == nil,
                isEnabled: draft.isEnabled,
                scale: scale
            ) {
                activePicker = .measurement
            }

            timeButton(
                title: "취침 알림",
                value: draft.bedtime.map(Self.formattedTime) ?? "시간을 선택해주세요",
                isPlaceholder: draft.bedtime == nil,
                isEnabled: draft.isEnabled,
                scale: scale
            ) {
                activePicker = .bedtime
            }
        }
    }

    private func timeButton(
        title: String,
        value: String,
        isPlaceholder: Bool,
        isEnabled: Bool,
        scale: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard isEnabled else { return }
            action()
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 13 * scale, weight: .regular))
                    .foregroundStyle(.white.opacity(isEnabled ? 0.7 : 0.32))

                Spacer()

                Text(value)
                    .font(.system(size: (isPlaceholder ? 12 : 15) * scale, weight: isPlaceholder ? .medium : .semibold))
                    .foregroundStyle(.white.opacity(isEnabled ? (isPlaceholder ? 0.48 : 1) : 0.32))

                Text("▾")
                    .font(.system(size: 12 * scale, weight: .medium))
                    .foregroundStyle(.white.opacity(isEnabled ? 0.5 : 0.25))
            }
            .padding(.horizontal, 16 * scale)
            .frame(maxWidth: .infinity)
            .frame(height: 52 * scale)
            .background(Color.myPageNotificationCard.opacity(isEnabled ? 1 : 0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12 * scale, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12 * scale, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func channelSection(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10 * scale) {
            sectionTitle("수신 채널", scale: scale)

            HStack(spacing: 10 * scale) {
                ForEach(MyPageNotificationChannel.allCases) { channel in
                    notificationChannelButton(channel, scale: scale)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .opacity(draft.isEnabled ? 1 : 0.45)
    }

    private func notificationChannelButton(_ channel: MyPageNotificationChannel, scale: CGFloat) -> some View {
        let isSelected = draft.channels.contains(channel)

        return Button {
            guard draft.isEnabled else { return }

            if isSelected {
                draft.channels.remove(channel)
            } else {
                draft.channels.insert(channel)
            }
        } label: {
            HStack(spacing: 10 * scale) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.myPageNotificationCyan : .clear)
                        .overlay {
                            Circle()
                                .stroke(.white.opacity(0.3), lineWidth: 1.2)
                        }

                    if isSelected {
                        Text("✓")
                            .font(.system(size: 9 * scale, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 16 * scale, height: 16 * scale)

                Text("\(channel.icon)  \(channel.title)")
                    .font(.system(size: 12 * scale, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12 * scale)
            .frame(width: 152 * scale)
            .frame(height: 36 * scale)
            .background(Color.myPageNotificationCard)
            .clipShape(RoundedRectangle(cornerRadius: 8 * scale, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8 * scale, style: .continuous)
                    .stroke(.white.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(!draft.isEnabled)
    }

    private func saveButton(scale: CGFloat) -> some View {
        Button {
            guard canSave else { return }
            onSave(draft)
            onBack()
        } label: {
            Text("저장하기")
                .font(.system(size: 16 * scale, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52 * scale)
                .background(
                    LinearGradient(
                        colors: canSave
                        ? [
                            Color(red: 0.49, green: 0.36, blue: 1),
                            Color(red: 0.13, green: 0.83, blue: 0.93)
                        ]
                        : [
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.12)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
    }

    private var canSave: Bool {
        guard draft.isEnabled else { return true }

        return !draft.channels.isEmpty
    }

    private var notificationToggleDescription: String {
        if isRequestingNotificationPermission {
            return "알림 권한을 확인하고 있어요"
        }

        return draft.isEnabled ? "측정과 수면 알림을 받을 수 있어요" : "알림 시간과 수신 채널 설정이 비활성화돼요"
    }

    private func setNotificationEnabled(_ isEnabled: Bool) {
        guard isEnabled else {
            draft.isEnabled = false
            return
        }

        Task {
            await enableNotificationIfPossible()
        }
    }

    @MainActor
    private func enableNotificationIfPossible() async {
        guard !isRequestingNotificationPermission else { return }

        isRequestingNotificationPermission = true
        defer { isRequestingNotificationPermission = false }

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            draft.isEnabled = true
        case .notDetermined:
            do {
                let isGranted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                draft.isEnabled = isGranted

                if !isGranted {
                    notificationPermissionMessage = "알림을 받으려면 iOS 설정에서 BLT 알림 권한을 허용해주세요."
                    showsNotificationSettingsAlert = true
                }
            } catch {
                draft.isEnabled = false
                notificationPermissionMessage = "알림 권한 요청을 완료하지 못했어요. iOS 설정에서 알림을 허용해주세요."
                showsNotificationSettingsAlert = true
            }
        case .denied:
            draft.isEnabled = false
            notificationPermissionMessage = "iOS 설정에서 BLT 알림 권한이 꺼져 있어요. 알림을 받으려면 설정에서 알림을 허용해주세요."
            showsNotificationSettingsAlert = true
        @unknown default:
            draft.isEnabled = false
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    @MainActor
    private func enableNotificationAfterReturningFromSettings() async {
        shouldEnableAfterReturningFromSettings = false

        let settings = await UNUserNotificationCenter.current().notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            draft.isEnabled = true
        case .denied, .notDetermined:
            draft.isEnabled = false
        @unknown default:
            draft.isEnabled = false
        }
    }

    private func sectionTitle(_ title: String, scale: CGFloat) -> some View {
        Text(title)
            .font(.system(size: 11 * scale, weight: .semibold))
            .tracking(1)
            .foregroundStyle(.white.opacity(0.55))
    }

    @ViewBuilder
    private func pickerSheet(for picker: NotificationTimePicker) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(picker.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)

                Spacer()

                Button("완료") {
                    confirmPickerSelection(picker)
                    activePicker = nil
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.myPageNotificationPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            DatePicker(
                picker.title,
                selection: Binding(
                    get: { selectedDate(for: picker) },
                    set: { setDate($0, for: picker) }
                ),
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "en_US_POSIX"))
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.myPageNotificationBackground)
    }

    private func selectedDate(for picker: NotificationTimePicker) -> Date {
        switch picker {
        case .measurement:
            return draft.measurementTime ?? Self.defaultMeasurementTime
        case .bedtime:
            return draft.bedtime ?? Self.defaultBedtime
        }
    }

    private func setDate(_ date: Date, for picker: NotificationTimePicker) {
        switch picker {
        case .measurement:
            draft.measurementTime = date
        case .bedtime:
            draft.bedtime = date
        }
    }

    private func confirmPickerSelection(_ picker: NotificationTimePicker) {
        setDate(selectedDate(for: picker), for: picker)
    }

    nonisolated private static var defaultMeasurementTime: Date {
        Calendar.current.date(bySettingHour: 7, minute: 30, second: 0, of: Date()) ?? Date()
    }

    nonisolated private static var defaultBedtime: Date {
        Calendar.current.date(bySettingHour: 23, minute: 30, second: 0, of: Date()) ?? Date()
    }

    nonisolated private static func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct MyPageNotificationEditDraft {
    var isEnabled: Bool
    var measurementTime: Date?
    var bedtime: Date?
    var channels: Set<MyPageNotificationChannel>

    init(settings: MyPageNotificationSettings) {
        isEnabled = settings.isEnabled
        measurementTime = Self.date(from: settings.measurementTimeText)
        bedtime = Self.date(from: settings.bedtimeText)
        channels = settings.channels
    }

    var settingsValue: MyPageNotificationSettings {
        MyPageNotificationSettings(
            isEnabled: isEnabled,
            measurementTimeText: measurementTime.map(Self.formattedTime),
            bedtimeText: bedtime.map(Self.formattedTime),
            channels: channels
        )
    }

    func patchRequest(comparedTo settings: MyPageNotificationSettings) -> MyPageNotificationPatchRequest {
        let measurementText = measurementTime.map(Self.formattedTime)
        let bedtimeText = bedtime.map(Self.formattedTime)

        return MyPageNotificationPatchRequest(
            isEnabled: isEnabled == settings.isEnabled ? nil : isEnabled,
            measurementTimeText: measurementText == settings.measurementTimeText ? nil : measurementText,
            bedtimeText: bedtimeText == settings.bedtimeText ? nil : bedtimeText,
            channels: channels == settings.channels ? nil : channels
        )
    }

    nonisolated private static func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    nonisolated private static func date(from text: String?) -> Date? {
        guard let text else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for format in ["HH:mm", "hh:mm a", "hh : mm a"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) {
                return date
            }
        }

        return nil
    }
}

private enum NotificationTimePicker: String, Identifiable {
    case measurement
    case bedtime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .measurement:
            return "측정 알림"
        case .bedtime:
            return "취침 알림"
        }
    }
}

private extension Color {
    static let myPageNotificationBackground = Color(red: 0.039, green: 0.055, blue: 0.153)
    static let myPageNotificationCard = Color(red: 0.078, green: 0.098, blue: 0.216)
    static let myPageNotificationPrimary = Color(red: 0.486, green: 0.361, blue: 1)
    static let myPageNotificationCyan = Color(red: 0.133, green: 0.827, blue: 0.933)
}
