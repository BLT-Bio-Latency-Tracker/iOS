import SwiftUI

struct NotificationsView: View {
    @StateObject private var viewModel = NotificationsViewModel()

    let onBack: () -> Void

    private let designWidth: CGFloat = 390

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / designWidth
            let contentWidth = max(0, proxy.size.width - 32 * scale)
            let horizontalInset = (proxy.size.width - contentWidth) / 2
            let topPadding = max(8 * scale, 56 * scale - proxy.safeAreaInsets.top)

            ZStack {
                Color.notificationBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        header(scale: scale)
                            .padding(.top, topPadding)

                        filterRow(scale: scale)
                            .padding(.top, 24 * scale)

                        notificationContent(scale: scale)
                            .padding(.top, 27 * scale)

                        footer(scale: scale)
                            .padding(.top, 34 * scale)
                            .padding(.bottom, 34 * scale)
                    }
                    .padding(.horizontal, horizontalInset)
                    .frame(minHeight: proxy.size.height, alignment: .top)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await viewModel.fetchNotifications()
        }
    }

    private func header(scale: CGFloat) -> some View {
        ZStack {
            Text("알림")
                .font(.system(size: 16 * scale, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)

            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 18 * scale, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32 * scale, height: 32 * scale)
                        .background(Color.notificationCard)
                        .clipShape(RoundedRectangle(cornerRadius: 10 * scale, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("뒤로가기")

                Spacer()
            }
        }
        .frame(height: 32 * scale)
    }

    private func filterRow(scale: CGFloat) -> some View {
        HStack(spacing: 8 * scale) {
            ForEach(AppNotificationCategory.allCases) { category in
                filterChip(category, scale: scale)
            }

            Spacer(minLength: 8 * scale)

            Button {
                Task {
                    await viewModel.markAllAsRead()
                }
            } label: {
                Text("모두 읽음")
                    .font(.system(size: 13 * scale, weight: .semibold))
                    .foregroundStyle(Color.notificationCyan)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.hasUnreadNotifications)
            .opacity(viewModel.hasUnreadNotifications ? 1 : 0.55)
            .accessibilityLabel("모든 알림 읽음 처리")
        }
    }

    private func filterChip(_ category: AppNotificationCategory, scale: CGFloat) -> some View {
        let isSelected = viewModel.selectedCategory == category
        let width: CGFloat = category == .all ? 64 : 80

        return Button {
            viewModel.selectCategory(category)
        } label: {
            Text(category.title)
                .font(.system(size: 12 * scale, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : Color.notificationMutedText)
                .frame(width: width * scale, height: 30 * scale)
                .background(isSelected ? Color.notificationPrimary : Color.clear)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(isSelected ? Color.clear : Color.notificationBorder, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func notificationContent(scale: CGFloat) -> some View {
        if viewModel.isLoading && viewModel.sectionGroups.isEmpty {
            loadingState(scale: scale)
        } else if let errorMessage = viewModel.errorMessage, viewModel.sectionGroups.isEmpty {
            errorState(errorMessage, scale: scale)
        } else if viewModel.sectionGroups.isEmpty {
            emptyState(scale: scale)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(viewModel.sectionGroups) { group in
                    section(group, scale: scale)
                        .padding(.top, group.section == viewModel.sectionGroups.first?.section ? 0 : 36 * scale)
                }
            }
        }
    }

    private func section(_ group: AppNotificationSectionGroup, scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(group.section.title)
                .font(.system(size: 13 * scale, weight: .semibold))
                .foregroundStyle(Color.notificationMutedText)
                .padding(.leading, 7 * scale)

            VStack(spacing: 12 * scale) {
                ForEach(group.items) { item in
                    notificationCard(item, scale: scale)
                }
            }
            .padding(.top, 20 * scale)
        }
    }

    private func notificationCard(_ item: AppNotificationItem, scale: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 12 * scale) {
            Circle()
                .fill(item.isRead ? Color.clear : Color.notificationCyan)
                .frame(width: 6 * scale, height: 6 * scale)
                .padding(.leading, 10 * scale)
                .accessibilityHidden(true)

            ZStack {
                Circle()
                    .fill(iconBackgroundColor(for: item))

                Text(item.icon)
                    .font(.system(size: iconFontSize(for: item) * scale))
                    .frame(width: 40 * scale, height: 40 * scale)
            }
            .frame(width: 40 * scale, height: 40 * scale)

            VStack(alignment: .leading, spacing: 0) {
                Text(item.title)
                    .font(.system(size: 14 * scale, weight: .semibold))
                    .foregroundStyle(item.isRead ? Color.notificationMutedText : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(item.message)
                    .font(.system(size: 11 * scale, weight: .regular))
                    .foregroundStyle(item.isRead ? Color.notificationSubtleText : Color.notificationMutedText)
                    .lineLimit(2)
                    .lineSpacing(2 * scale)
                    .minimumScaleFactor(0.86)
                    .padding(.top, 5 * scale)

                Text(item.timeText)
                    .font(.system(size: 10 * scale, weight: .regular))
                    .foregroundStyle(Color.notificationSubtleText)
                    .lineLimit(1)
                    .padding(.top, 12 * scale)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 12 * scale)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: cardHeight(for: item) * scale)
        .background(Color.notificationCard)
        .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
    }

    private func emptyState(scale: CGFloat) -> some View {
        VStack(spacing: 10 * scale) {
            Text("알림이 없어요")
                .font(.system(size: 15 * scale, weight: .semibold))
                .foregroundStyle(.white)

            Text("새로운 알림이 도착하면 이곳에 표시됩니다.")
                .font(.system(size: 12 * scale, weight: .regular))
                .foregroundStyle(Color.notificationMutedText)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120 * scale)
        .background(Color.notificationCard)
        .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
    }

    private func loadingState(scale: CGFloat) -> some View {
        VStack(spacing: 12 * scale) {
            ProgressView()
                .tint(.white)

            Text("알림을 불러오는 중이에요")
                .font(.system(size: 12 * scale, weight: .regular))
                .foregroundStyle(Color.notificationMutedText)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120 * scale)
        .background(Color.notificationCard)
        .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
    }

    private func errorState(_ message: String, scale: CGFloat) -> some View {
        VStack(spacing: 12 * scale) {
            Text(message)
                .font(.system(size: 13 * scale, weight: .semibold))
                .foregroundStyle(.white)

            Button {
                Task {
                    await viewModel.fetchNotifications()
                }
            } label: {
                Text("다시 시도")
                    .font(.system(size: 12 * scale, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 96 * scale, height: 32 * scale)
                    .background(Color.notificationPrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120 * scale)
        .background(Color.notificationCard)
        .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
    }

    private func footer(scale: CGFloat) -> some View {
        Text("알림 설정은 마이페이지에서 변경할 수 있어요")
            .font(.system(size: 11 * scale, weight: .regular))
            .foregroundStyle(Color.notificationSubtleText)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
    }

    private func iconBackgroundColor(for item: AppNotificationItem) -> Color {
        switch item.styleKey {
        case .morningMeasurement:
            return Color.notificationPrimary
        case .sleepReminder:
            return Color.notificationCaution
        case .weeklyReport:
            return Color.notificationPositive
        case .invalidMeasurement:
            return Color.notificationNegative
        case .system:
            return Color(red: 0.11, green: 0.137, blue: 0.275)
        }
    }

    private func iconFontSize(for item: AppNotificationItem) -> CGFloat {
        item.styleKey == .invalidMeasurement ? 18 : 20
    }

    private func cardHeight(for item: AppNotificationItem) -> CGFloat {
        item.message.contains("\n") ? 92 : 84
    }
}

private extension Color {
    static let notificationBackground = Color(red: 0.039, green: 0.055, blue: 0.153)
    static let notificationCard = Color(red: 0.078, green: 0.098, blue: 0.216)
    static let notificationBorder = Color(red: 0.2, green: 0.23, blue: 0.36)
    static let notificationPrimary = Color(red: 0.486, green: 0.361, blue: 1)
    static let notificationCyan = Color(red: 0.133, green: 0.827, blue: 0.933)
    static let notificationCaution = Color(red: 0.961, green: 0.62, blue: 0.043)
    static let notificationPositive = Color(red: 0.063, green: 0.725, blue: 0.506)
    static let notificationNegative = Color(red: 0.937, green: 0.267, blue: 0.267)
    static let notificationMutedText = Color(red: 0.7, green: 0.72, blue: 0.82)
    static let notificationSubtleText = Color(red: 0.45, green: 0.47, blue: 0.6)
}
