import SwiftUI

struct MyPageView: View {
    @StateObject private var viewModel = MyPageViewModel()
    @State private var editDestination: MyPageEditDestination?

    let onBack: () -> Void

    private let designWidth: CGFloat = 390

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / designWidth
            let contentWidth = max(0, proxy.size.width - 48 * scale)
            let horizontalInset = (proxy.size.width - contentWidth) / 2
            let topPadding = max(8 * scale, 56 * scale - proxy.safeAreaInsets.top)

            ZStack {
                Color.myPageBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        header(scale: scale)
                            .padding(.top, topPadding)

                        if let state = viewModel.state {
                            if !state.isProfileComplete {
                                incompleteBanner(scale: scale)
                                    .padding(.top, 22 * scale)
                            }

                            profileCard(state.user, scale: scale)
                                .padding(.top, state.isProfileComplete ? 28 * scale : 18 * scale)

                            profileSection(state, scale: scale)
                                .padding(.top, 24 * scale)

                            notificationSection(state.notificationSettings, scale: scale)
                                .padding(.top, 26 * scale)

                            accountSection(scale: scale)
                                .padding(.top, 26 * scale)
                                .padding(.bottom, 34 * scale)
                        } else {
                            loadingState(scale: scale)
                                .padding(.top, 160 * scale)
                        }
                    }
                    .padding(.horizontal, horizontalInset)
                    .frame(minHeight: proxy.size.height, alignment: .top)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await viewModel.fetchMyPage()
        }
        .fullScreenCover(item: $editDestination) { destination in
            MyPageEditPlaceholderView(destination: destination) {
                editDestination = nil
            }
            .ignoresSafeArea()
        }
    }

    private func header(scale: CGFloat) -> some View {
        ZStack {
            Text("마이페이지")
                .font(.system(size: 16 * scale, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)

            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18 * scale, weight: .semibold))
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

    private func incompleteBanner(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10 * scale) {
            HStack(spacing: 7 * scale) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13 * scale, weight: .bold))
                    .foregroundStyle(Color.myPageWarningText)

                Text("프로필 미완성")
                    .font(.system(size: 14 * scale, weight: .bold))
                    .foregroundStyle(Color.myPageWarningText)
            }

            Text("프로필을 완성하면 측정 정확도가 +30% 향상돼요")
                .font(.system(size: 13 * scale, weight: .medium))
                .foregroundStyle(Color.myPageWarningText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 18 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 74 * scale)
        .background(Color.myPageWarning)
        .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
    }

    private func profileCard(_ user: MyPageUser, scale: CGFloat) -> some View {
        HStack(spacing: 16 * scale) {
            Text(user.profileInitial)
                .font(.system(size: 24 * scale, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 52 * scale, height: 52 * scale)
                .background(Color.myPagePrimary)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6 * scale) {
                Text(user.name)
                    .font(.system(size: 20 * scale, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("\(user.email) · \(user.authProvider)")
                    .font(.system(size: 12 * scale, weight: .regular))
                    .foregroundStyle(Color.myPageMutedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16 * scale)
        .frame(maxWidth: .infinity)
        .frame(height: 84 * scale)
        .background(Color.myPageCard)
        .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
    }

    private func profileSection(_ state: MyPageState, scale: CGFloat) -> some View {
        section(
            title: "내 정보",
            trailing: profileMissingText(for: state),
            scale: scale,
            action: {
                editDestination = .profile
            }
        ) {
            infoRows([
                MyPageRow(title: "출생연도", value: state.profile.birthYear.map { "\($0)년" } ?? "미설정", isWarning: state.profile.birthYear == nil),
                MyPageRow(title: "성별", value: state.profile.gender?.displayName ?? "미설정", isWarning: state.profile.gender == nil),
                MyPageRow(title: "평균 기상시간", value: state.profile.wakeUpTimeText ?? "미설정", isWarning: state.profile.wakeUpTimeText == nil),
                MyPageRow(title: "직업군", value: state.profile.jobGroup?.rawValue ?? "미설정", isWarning: state.profile.jobGroup == nil)
            ], scale: scale)
        }
    }

    private func notificationSection(_ settings: MyPageNotificationSettings, scale: CGFloat) -> some View {
        section(
            title: "알림 설정",
            trailing: nil,
            scale: scale,
            action: {
                editDestination = .notification
            }
        ) {
            infoRows([
                MyPageRow(title: "알림", value: settings.isEnabled ? "ON" : "OFF", isWarning: false),
                MyPageRow(title: "측정 알림", value: settings.measurementTimeText ?? "미설정", isWarning: settings.measurementTimeText == nil),
                MyPageRow(title: "취침 알림", value: settings.bedtimeText ?? "미설정", isWarning: settings.bedtimeText == nil)
            ], scale: scale)
        }
    }

    private func accountSection(scale: CGFloat) -> some View {
        section(title: "약관 · 계정", trailing: nil, scale: scale) {
            VStack(spacing: 0) {
                accountRow("약관 동의 이력", scale: scale)
                divider(scale: scale)
                accountRow("내 데이터 다운로드", scale: scale)
                divider(scale: scale)
                accountRow("회원 탈퇴", isDestructive: true, scale: scale)
            }
        }
    }

    private func section<Content: View>(
        title: String,
        trailing: String?,
        scale: CGFloat,
        action: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10 * scale) {
            Button {
                action?()
            } label: {
                sectionHeader(title: title, trailing: trailing, showsChevron: action != nil, scale: scale)
            }
            .buttonStyle(.plain)
            .disabled(action == nil)

            content()
                .padding(.horizontal, 16 * scale)
                .padding(.vertical, 6 * scale)
                .background(Color.myPageCard)
                .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
        }
    }

    private func sectionHeader(
        title: String,
        trailing: String?,
        showsChevron: Bool,
        scale: CGFloat
    ) -> some View {
        HStack(spacing: 6 * scale) {
            Text(title)
                .font(.system(size: 13 * scale, weight: .semibold))
                .foregroundStyle(Color.myPageMutedText)

            Spacer()

            if let trailing {
                Text(trailing)
                    .font(.system(size: 12 * scale, weight: .semibold))
                    .foregroundStyle(Color.myPageWarning)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11 * scale, weight: .semibold))
                    .foregroundStyle(trailing == nil ? Color.myPageMutedText : Color.myPageWarning)
            }
        }
        .padding(.horizontal, 8 * scale)
        .contentShape(Rectangle())
    }

    private func infoRows(_ rows: [MyPageRow], scale: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack {
                    Text(row.title)
                        .font(.system(size: 13 * scale, weight: .regular))
                        .foregroundStyle(Color.myPageMutedText)

                    Spacer(minLength: 16 * scale)

                    Text(row.value)
                        .font(.system(size: 13 * scale, weight: .regular))
                        .foregroundStyle(row.isWarning ? Color.myPageSubtleText : .white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                }
                .frame(height: 32 * scale)

                if index < rows.count - 1 {
                    divider(scale: scale)
                }
            }
        }
    }

    private func accountRow(_ title: String, isDestructive: Bool = false, scale: CGFloat) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13 * scale, weight: .regular))
                .foregroundStyle(isDestructive ? Color.myPageDanger : Color.myPageMutedText)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11 * scale, weight: .semibold))
                .foregroundStyle(Color.myPageSubtleText)
        }
        .frame(height: 32 * scale)
    }

    private func divider(scale: CGFloat) -> some View {
        Rectangle()
            .fill(Color.myPageDivider)
            .frame(height: 1)
    }

    private func loadingState(scale: CGFloat) -> some View {
        Text("마이페이지 정보를 불러오는 중...")
            .font(.system(size: 13 * scale, weight: .medium))
            .foregroundStyle(Color.myPageMutedText)
            .frame(maxWidth: .infinity)
    }

    private func profileMissingText(for state: MyPageState) -> String? {
        guard !state.isProfileComplete else { return nil }
        return "\(state.missingProfileItemCount) / 4 미설정"
    }
}

private struct MyPageRow {
    let title: String
    let value: String
    let isWarning: Bool
}

private enum MyPageEditDestination: String, Identifiable {
    case profile
    case notification

    var id: String { rawValue }

    var title: String {
        switch self {
        case .profile:
            return "내 정보 수정"
        case .notification:
            return "알림 설정"
        }
    }

    var message: String {
        switch self {
        case .profile:
            return "내 정보 수정 화면은 서버 프로필 저장 API와 함께 연결할 예정입니다."
        case .notification:
            return "알림 설정 화면은 알림 권한과 서버 설정 API가 확정되면 연결할 예정입니다."
        }
    }
}

private struct MyPageEditPlaceholderView: View {
    let destination: MyPageEditDestination
    let onBack: () -> Void

    private let designWidth: CGFloat = 390

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / designWidth
            let contentWidth = max(0, proxy.size.width - 48 * scale)
            let horizontalInset = (proxy.size.width - contentWidth) / 2
            let topPadding = max(8 * scale, 56 * scale - proxy.safeAreaInsets.top)

            ZStack {
                Color.myPageBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header(scale: scale)
                        .padding(.top, topPadding)

                    Spacer()

                    VStack(spacing: 12 * scale) {
                        Text(destination.title)
                            .font(.system(size: 22 * scale, weight: .bold))
                            .foregroundStyle(.white)

                        Text(destination.message)
                            .font(.system(size: 13 * scale, weight: .regular))
                            .foregroundStyle(Color.myPageMutedText)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4 * scale)
                    }
                    .padding(.horizontal, 20 * scale)

                    Spacer()
                }
                .padding(.horizontal, horizontalInset)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func header(scale: CGFloat) -> some View {
        ZStack {
            Text(destination.title)
                .font(.system(size: 16 * scale, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)

            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18 * scale, weight: .semibold))
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
}

private extension Color {
    static let myPageBackground = Color(red: 0.039, green: 0.055, blue: 0.153)
    static let myPageCard = Color(red: 0.078, green: 0.098, blue: 0.216)
    static let myPageDivider = Color(red: 0.2, green: 0.23, blue: 0.36)
    static let myPagePrimary = Color(red: 0.486, green: 0.361, blue: 1)
    static let myPageMutedText = Color(red: 0.7, green: 0.72, blue: 0.82)
    static let myPageSubtleText = Color(red: 0.45, green: 0.47, blue: 0.6)
    static let myPageWarning = Color(red: 0.961, green: 0.62, blue: 0.043)
    static let myPageWarningText = Color(red: 0.039, green: 0.055, blue: 0.153)
    static let myPageDanger = Color(red: 0.937, green: 0.267, blue: 0.267)
}
