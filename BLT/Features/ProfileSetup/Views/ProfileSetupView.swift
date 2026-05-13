import SwiftUI

struct ProfileSetupDraft {
    var birthYear: Int?
    var gender: ProfileSetupGender?
    var wakeUpTime: Date?
    var jobGroup: ProfileSetupJobGroup?

    var isComplete: Bool {
        birthYear != nil && gender != nil && wakeUpTime != nil && jobGroup != nil
    }
}

enum ProfileSetupGender: String, CaseIterable, Identifiable {
    case male = "남"
    case female = "여"
    case other = "기타"
    case preferNotToSay = "응답 안함"

    var id: String { rawValue }
}

enum ProfileSetupJobGroup: String, CaseIterable, Identifiable {
    case knowledge = "지식 노동"
    case field = "현장 노동"
    case student = "학생"
    case other = "기타"

    var id: String { rawValue }
}

struct ProfileSetupView: View {
    @Binding var setupDraft: ProfileSetupDraft

    var onBack: () -> Void = {}
    var onNext: () -> Void = {}
    var onSkip: () -> Void = {}

    @State private var activePicker: ActivePicker?

    private let designWidth: CGFloat = 375
    private let designHeight: CGFloat = 812
    private let birthYears = Array((1940...2026).reversed())

    private var canMoveNext: Bool {
        setupDraft.isComplete
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / designWidth, proxy.size.height / designHeight)
            let contentWidth = min(proxy.size.width - 24, 351 * scale)
            let horizontalInset = max(12, (proxy.size.width - contentWidth) / 2)

            ZStack {
                Color(red: 0.039, green: 0.055, blue: 0.153)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header(scale: scale)
                        .padding(.top, 56 * scale)
                        .padding(.horizontal, horizontalInset)

                    titleSection(scale: scale)
                        .padding(.top, 27 * scale)
                        .padding(.horizontal, horizontalInset)

                    formSection(scale: scale)
                        .padding(.top, 26 * scale)
                        .padding(.horizontal, horizontalInset)

                    Spacer(minLength: 0)

                    bottomActions(scale: scale)
                        .padding(.horizontal, horizontalInset)
                        .padding(.bottom, max(55, 55 * scale))
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
    }

    private func header(scale: CGFloat) -> some View {
        HStack {
            Button(action: onBack) {
                Text("←")
                    .font(.system(size: 16 * scale, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 32 * scale, height: 32 * scale)
                    .background(.clear)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.15), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

            Spacer()

            Text("2 / 2")
                .font(.system(size: 11 * scale, weight: .semibold))
                .foregroundStyle(Color(red: 0.486, green: 0.361, blue: 1))
                .frame(width: 56 * scale, height: 22 * scale)
                .background(Color(red: 0.486, green: 0.361, blue: 1).opacity(0.18))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color(red: 0.486, green: 0.361, blue: 1).opacity(0.4), lineWidth: 1)
                }
        }
    }

    private func titleSection(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14 * scale) {
            Text("더 정확한 측정을 위해\n몇 가지만 알려주세요")
                .font(.system(size: 24 * scale, weight: .heavy))
                .foregroundStyle(.white)
                .lineSpacing(5 * scale)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("모두 선택사항입니다 · 나중에 변경 가능")
                .font(.system(size: 12 * scale, weight: .regular))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func formSection(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 20 * scale) {
            dropdownSection(
                title: "출생 연도",
                value: setupDraft.birthYear.map(String.init) ?? "선택해주세요",
                scale: scale
            ) {
                activePicker = .birthYear
            }

            genderSection(scale: scale)

            dropdownSection(
                title: "평균 기상 시간",
                value: setupDraft.wakeUpTime.map(formattedWakeUpTime) ?? "선택해주세요",
                scale: scale
            ) {
                activePicker = .wakeUpTime
            }

            jobGroupSection(scale: scale)
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
                        .font(.system(size: 16 * scale, weight: .semibold))
                        .foregroundStyle(value == "선택해주세요" ? .white.opacity(0.45) : .white)

                    Spacer()

                    Text("▾")
                        .font(.system(size: 14 * scale, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.horizontal, 16 * scale)
                .frame(maxWidth: .infinity)
                .frame(height: 52 * scale)
                .background(Color(red: 0.078, green: 0.098, blue: 0.216))
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
                        item.rawValue,
                        isSelected: setupDraft.gender == item,
                        scale: scale
                    ) {
                        setupDraft.gender = item
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
                        setupDraft.jobGroup = item
                    } label: {
                        Text(item.rawValue)
                            .font(.system(size: 12 * scale, weight: setupDraft.jobGroup == item ? .semibold : .medium))
                            .foregroundStyle(.white.opacity(setupDraft.jobGroup == item ? 1 : 0.6))
                            .frame(maxWidth: .infinity)
                            .frame(height: 28 * scale)
                            .background(
                                RoundedRectangle(cornerRadius: 6 * scale, style: .continuous)
                                    .fill(setupDraft.jobGroup == item ? Color(red: 0.486, green: 0.361, blue: 1) : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4 * scale)
            .frame(maxWidth: .infinity)
            .frame(height: 36 * scale)
            .background(Color(red: 0.078, green: 0.098, blue: 0.216))
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
                .font(.system(size: 13 * scale, weight: .medium))
                .foregroundStyle(.white.opacity(isSelected ? 1 : 0.7))
                .padding(.horizontal, chipHorizontalPadding(for: title, scale: scale))
                .frame(height: 36 * scale)
                .background(isSelected ? Color(red: 0.486, green: 0.361, blue: 1) : Color(red: 0.078, green: 0.098, blue: 0.216))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(isSelected ? .clear : .white.opacity(0.08), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private func chipHorizontalPadding(for title: String, scale: CGFloat) -> CGFloat {
        switch title {
        case "남", "여":
            return 24 * scale
        case "기타":
            return 22 * scale
        default:
            return 26 * scale
        }
    }

    private func sectionTitle(_ title: String, scale: CGFloat) -> some View {
        Text(title)
            .font(.system(size: 11 * scale, weight: .semibold))
            .tracking(1)
            .foregroundStyle(.white.opacity(0.55))
    }

    private func bottomActions(scale: CGFloat) -> some View {
        VStack(spacing: 20 * scale) {
            Button(action: onNext) {
                Text("다음")
                    .font(.system(size: 16 * scale, weight: .semibold))
                    .foregroundStyle(.white.opacity(canMoveNext ? 1 : 0.45))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52 * scale)
                    .background(Color(red: 0.486, green: 0.361, blue: 1).opacity(canMoveNext ? 1 : 0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canMoveNext)

            Button(action: onSkip) {
                Text("건너뛰기")
                    .font(.system(size: 14 * scale, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .frame(height: 17 * scale)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func pickerSheet(for picker: ActivePicker) -> some View {
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
                .foregroundStyle(Color(red: 0.486, green: 0.361, blue: 1))
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)

            switch picker {
            case .birthYear:
                Picker("출생 연도", selection: Binding(
                    get: { setupDraft.birthYear ?? 2000 },
                    set: { setupDraft.birthYear = $0 }
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
                        get: { setupDraft.wakeUpTime ?? defaultWakeUpTime },
                        set: { setupDraft.wakeUpTime = $0 }
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
        .background(Color(red: 0.039, green: 0.055, blue: 0.153))
    }

    private var defaultWakeUpTime: Date {
        Calendar.current.date(bySettingHour: 7, minute: 30, second: 0, of: Date()) ?? Date()
    }

    private func formattedWakeUpTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "hh : mm a"
        return formatter.string(from: date)
    }

    private func confirmPickerSelection(_ picker: ActivePicker) {
        switch picker {
        case .birthYear:
            setupDraft.birthYear = setupDraft.birthYear ?? 2000
        case .wakeUpTime:
            setupDraft.wakeUpTime = setupDraft.wakeUpTime ?? defaultWakeUpTime
        }
    }
}

private enum ActivePicker: Identifiable {
    case birthYear
    case wakeUpTime

    var id: String {
        switch self {
        case .birthYear:
            return "birthYear"
        case .wakeUpTime:
            return "wakeUpTime"
        }
    }

    var title: String {
        switch self {
        case .birthYear:
            return "출생 연도"
        case .wakeUpTime:
            return "평균 기상 시간"
        }
    }
}
