import SwiftUI

struct MyPageProfileEditView: View {
    let state: MyPageState
    let onBack: () -> Void
    let onSave: (MyPageProfileEditDraft) async -> Bool

    @State private var draft: MyPageProfileEditDraft
    @State private var activePicker: MyPageProfileEditPicker?
    @FocusState private var focusedField: FocusedField?

    private let designWidth: CGFloat = 375
    private let designHeight: CGFloat = 812
    private var birthYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((1940...currentYear).reversed())
    }

    init(
        state: MyPageState,
        onBack: @escaping () -> Void,
        onSave: @escaping (MyPageProfileEditDraft) async -> Bool
    ) {
        self.state = state
        self.onBack = onBack
        self.onSave = onSave
        _draft = State(initialValue: MyPageProfileEditDraft(state: state))
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / designWidth, proxy.size.height / designHeight)
            let contentWidth = min(proxy.size.width - 24, 351 * scale)
            let horizontalInset = max(12, (proxy.size.width - contentWidth) / 2)
            let topPadding = max(8 * scale, 56 * scale - proxy.safeAreaInsets.top)

            ZStack {
                Color.myPageBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header(scale: scale)
                        .padding(.top, topPadding)
                        .padding(.horizontal, horizontalInset)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 20 * scale) {
                            nameSection(scale: scale)
                            birthYearSection(scale: scale)
                            genderSection(scale: scale)
                            wakeUpTimeSection(scale: scale)
                            jobGroupSection(scale: scale)
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
            .contentShape(Rectangle())
            .onTapGesture {
                focusedField = nil
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $activePicker) { picker in
            pickerSheet(for: picker)
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
    }

    private func header(scale: CGFloat) -> some View {
        ZStack {
            Text("내 정보 수정")
                .brykiTextStyle(size: 16 * scale, weight: SwiftUI.Font.Weight.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)

            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .brykiTextStyle(size: 18 * scale, weight: SwiftUI.Font.Weight.semibold)
                        .foregroundStyle(.white)
                        .frame(width: 32 * scale, height: 32 * scale)
                        .background(Color.myPageCard)
                        .clipShape(RoundedRectangle(cornerRadius: 10 * scale, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("뒤로가기")

                Spacer()
            }
        }
        .frame(height: 32 * scale)
    }

    private func nameSection(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 7 * scale) {
            sectionTitle("이름", scale: scale)

            TextField("이름을 입력해주세요", text: $draft.name)
                .brykiTextStyle(size: 16 * scale, weight: SwiftUI.Font.Weight.semibold)
                .foregroundStyle(.white)
                .focused($focusedField, equals: .name)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .onSubmit {
                    focusedField = nil
                }
                .padding(.horizontal, 16 * scale)
                .frame(maxWidth: .infinity)
                .frame(height: 52 * scale)
                .background(Color.myPageCard)
                .clipShape(RoundedRectangle(cornerRadius: 12 * scale, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12 * scale, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                }
        }
    }

    private func birthYearSection(scale: CGFloat) -> some View {
        dropdownSection(
            title: "출생 연도",
            value: draft.birthYear.map(String.init) ?? "선택해주세요",
            scale: scale
        ) {
            activePicker = .birthYear
        }
    }

    private func wakeUpTimeSection(scale: CGFloat) -> some View {
        dropdownSection(
            title: "평균 기상 시간",
            value: draft.wakeUpTime.map(Self.formattedWakeUpTime) ?? "선택해주세요",
            scale: scale
        ) {
            activePicker = .wakeUpTime
        }
    }

    private func dropdownSection(
        title: String,
        value: String,
        scale: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 7 * scale) {
            sectionTitle(title, scale: scale)

            Button(action: action) {
                HStack {
                    Text(value)
                        .brykiTextStyle(size: 16 * scale, weight: SwiftUI.Font.Weight.semibold)
                        .foregroundStyle(value == "선택해주세요" ? .white.opacity(0.45) : .white)

                    Spacer()

                    Text("▾")
                        .brykiTextStyle(size: 14 * scale, weight: SwiftUI.Font.Weight.medium)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 16 * scale)
                .frame(maxWidth: .infinity)
                .frame(height: 52 * scale)
                .background(Color.myPageCard)
                .clipShape(RoundedRectangle(cornerRadius: 12 * scale, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12 * scale, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func genderSection(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 7 * scale) {
            sectionTitle("성별", scale: scale)

            HStack(spacing: 7 * scale) {
                ForEach(ProfileSetupGender.allCases) { item in
                    selectableChip(
                        item.displayName,
                        isSelected: draft.gender == item,
                        scale: scale
                    ) {
                        draft.gender = item
                    }
                }
            }
        }
    }

    private func jobGroupSection(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 7 * scale) {
            sectionTitle("직업군", scale: scale)

            HStack(spacing: 0) {
                ForEach(ProfileSetupJobGroup.allCases) { item in
                    Button {
                        draft.jobGroup = item
                    } label: {
                        Text(item.displayName)
                            .brykiTextStyle(
                                size: 12 * scale,
                                weight: draft.jobGroup == item
                                    ? SwiftUI.Font.Weight.semibold
                                    : SwiftUI.Font.Weight.medium
                            )
                            .foregroundStyle(.white.opacity(draft.jobGroup == item ? 1 : 0.6))
                            .frame(maxWidth: .infinity)
                            .frame(height: 28 * scale)
                            .background(
                                RoundedRectangle(cornerRadius: 6 * scale, style: .continuous)
                                    .fill(draft.jobGroup == item ? Color.myPagePrimary : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4 * scale)
            .frame(maxWidth: .infinity)
            .frame(height: 36 * scale)
            .background(Color.myPageCard)
            .clipShape(RoundedRectangle(cornerRadius: 8 * scale, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8 * scale, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
        }
    }

    private func selectableChip(
        _ title: String,
        isSelected: Bool,
        scale: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .brykiTextStyle(size: 13 * scale, weight: SwiftUI.Font.Weight.medium)
                .foregroundStyle(.white.opacity(isSelected ? 1 : 0.7))
                .frame(maxWidth: .infinity)
                .frame(height: 36 * scale)
                .background(isSelected ? Color.myPagePrimary : Color.myPageCard)
                .clipShape(RoundedRectangle(cornerRadius: 12 * scale, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12 * scale, style: .continuous)
                        .stroke(isSelected ? .clear : .white.opacity(0.08), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func saveButton(scale: CGFloat) -> some View {
        Button {
            focusedField = nil
            Task {
                let isSaved = await onSave(draft)

                if isSaved {
                    onBack()
                }
            }
        } label: {
            Text("저장하기")
                .brykiTextStyle(size: 16 * scale, weight: SwiftUI.Font.Weight.semibold)
                .foregroundStyle(.white.opacity(draft.canSave ? 1 : 0.45))
                .frame(maxWidth: .infinity)
                .frame(height: 52 * scale)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.49, green: 0.36, blue: 1),
                            Color(red: 0.13, green: 0.83, blue: 0.93)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    //.opacity(draft.canSave ? 1 : 0.35)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!draft.canSave)
    }

    private func sectionTitle(_ title: String, scale: CGFloat) -> some View {
        Text(title)
            .brykiTextStyle(size: 11 * scale, weight: SwiftUI.Font.Weight.semibold)
            .tracking(1)
            .foregroundStyle(.white.opacity(0.55))
    }

    @ViewBuilder
    private func pickerSheet(for picker: MyPageProfileEditPicker) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(picker.title)
                    .brykiTextStyle(size: 17, weight: SwiftUI.Font.Weight.semibold)
                    .foregroundStyle(.white)

                Spacer()

                Button("완료") {
                    confirmPickerSelection(picker)
                    activePicker = nil
                }
                .brykiTextStyle(size: 15, weight: SwiftUI.Font.Weight.semibold)
                .foregroundStyle(Color.myPagePrimary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            switch picker {
            case .birthYear:
                Picker("출생 연도", selection: Binding(
                    get: { draft.birthYear ?? 2000 },
                    set: { draft.birthYear = $0 }
                )) {
                    ForEach(birthYears, id: \.self) { year in
                        Text(String(year))
                            .tag(year)
                    }
                }
                .pickerStyle(.wheel)

            case .wakeUpTime:
                DatePicker(
                    "평균 기상 시간",
                    selection: Binding(
                        get: { draft.wakeUpTime ?? Self.defaultWakeUpTime },
                        set: { draft.wakeUpTime = $0 }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "en_US_POSIX"))
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.myPageBackground)
    }

    private func confirmPickerSelection(_ picker: MyPageProfileEditPicker) {
        switch picker {
        case .birthYear:
            draft.birthYear = draft.birthYear ?? 2000
        case .wakeUpTime:
            draft.wakeUpTime = draft.wakeUpTime ?? Self.defaultWakeUpTime
        }
    }

    nonisolated private static var defaultWakeUpTime: Date {
        Calendar.current.date(bySettingHour: 7, minute: 30, second: 0, of: Date()) ?? Date()
    }

    nonisolated private static func formattedWakeUpTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: date)
    }
}

struct MyPageProfileEditDraft {
    var name: String
    var birthYear: Int?
    var gender: ProfileSetupGender?
    var wakeUpTime: Date?
    var jobGroup: ProfileSetupJobGroup?

    init(state: MyPageState) {
        name = state.user.name
        birthYear = state.profile.birthYear
        gender = state.profile.gender
        wakeUpTime = Self.date(from: state.profile.wakeUpTimeText)
        jobGroup = state.profile.jobGroup
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var wakeUpTimeText: String? {
        wakeUpTime.map(Self.formattedWakeUpTime)
    }

    func patchRequest(comparedTo state: MyPageState) -> MyPageProfilePatchRequest {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        return MyPageProfilePatchRequest(
            name: trimmedName == state.user.name ? nil : trimmedName,
            birthYear: birthYear == state.profile.birthYear ? nil : birthYear,
            gender: gender == state.profile.gender ? nil : gender,
            wakeUpTimeText: wakeUpTimeText == state.profile.wakeUpTimeText ? nil : wakeUpTimeText,
            jobGroup: jobGroup == state.profile.jobGroup ? nil : jobGroup
        )
    }

    nonisolated private static func formattedWakeUpTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: date)
    }

    nonisolated private static func date(from text: String?) -> Date? {
        guard let text else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")

        for format in ["hh:mm a", "hh : mm a"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: text) {
                return date
            }
        }

        return nil
    }
}

private enum MyPageProfileEditPicker: String, Identifiable {
    case birthYear
    case wakeUpTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .birthYear:
            return "출생 연도"
        case .wakeUpTime:
            return "평균 기상 시간"
        }
    }
}

private enum FocusedField {
    case name
}

private extension Color {
    static let myPageBackground = Color(red: 0.039, green: 0.055, blue: 0.153)
    static let myPageCard = Color(red: 0.078, green: 0.098, blue: 0.216)
    static let myPagePrimary = Color(red: 0.486, green: 0.361, blue: 1)
}
