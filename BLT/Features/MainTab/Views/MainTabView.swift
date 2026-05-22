import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: MainTab = .home

    var body: some View {
        ZStack {
            Color.bltTabBackground
                .ignoresSafeArea()

            selectedContent
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear
                        .frame(height: 76)
                }

            VStack {
                Spacer()

                MainTabBar(selectedTab: $selectedTab)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .today:
            TodayView()

        case .home:
            HomeView()

        case .history:
            MainTabPlaceholderView(
                title: "History",
                subtitle: "측정 기록과 변화 추이를 준비 중이에요",
                systemImage: "chart.line.uptrend.xyaxis"
            )
        }
    }
}

private struct MainTabBar: View {
    @Binding var selectedTab: MainTab
    @Namespace private var selectedTabNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(MainTab.allCases) { tab in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                        selectedTab = tab
                    }
                } label: {
                    MainTabItem(
                        tab: tab,
                        isSelected: selectedTab == tab,
                        namespace: selectedTabNamespace
                    )
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(tab.title))
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(height: 60)
        .modifier(MainTabBarBackground())
    }
}

private struct MainTabItem: View {
    let tab: MainTab
    let isSelected: Bool
    let namespace: Namespace.ID

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: isSelected ? tab.selectedSystemImage : tab.systemImage)
                .font(.system(size: tab == .home ? 19 : 17, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 30, height: 23)

            Text(tab.title)
                .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                .lineLimit(1)
        }
        .foregroundStyle(isSelected ? Color.white : Color.bltTabMuted)
        .frame(height: 46)
        .frame(maxWidth: .infinity)
        .background {
            if isSelected {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.bltTabPrimary, Color.bltTabCyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.bltTabPrimary.opacity(0.28), radius: 14, x: 0, y: 8)
                    .matchedGeometryEffect(id: "selected-tab-background", in: namespace)
            }
        }
        .scaleEffect(isSelected ? 1.02 : 1)
    }
}

private struct MainTabBarBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .background {
                    Capsule()
                        .fill(Color.white.opacity(0.03))
                        .glassEffect(
                            .regular
                                .tint(Color.bltTabCard.opacity(0.68))
                                .interactive(),
                            in: Capsule()
                        )
                }
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.28), radius: 24, x: 0, y: 12)
        } else {
            content
                .background {
                    Capsule()
                        .fill(Color.bltTabCard.opacity(0.98))
                }
                .overlay {
                    Capsule()
                        .stroke(Color.bltTabBorder, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.24), radius: 18, x: 0, y: 10)
        }
    }
}

private struct MainTabPlaceholderView: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Color.bltTabCyan)
                .frame(width: 68, height: 68)
                .background(Color.bltTabCard)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text(title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color.bltTabMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }
}

private enum MainTab: String, CaseIterable, Identifiable {
    case today
    case home
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today:
            return "Today"
        case .home:
            return "Home"
        case .history:
            return "History"
        }
    }

    var systemImage: String {
        switch self {
        case .today:
            return "sun.max"
        case .home:
            return "house"
        case .history:
            return "clock.arrow.circlepath"
        }
    }

    var selectedSystemImage: String {
        switch self {
        case .today:
            return "sun.max.fill"
        case .home:
            return "house.fill"
        case .history:
            return "clock.arrow.circlepath"
        }
    }
}

private extension Color {
    static let bltTabBackground = Color(red: 0.039, green: 0.055, blue: 0.153)
    static let bltTabCard = Color(red: 0.078, green: 0.098, blue: 0.216)
    static let bltTabBorder = Color(red: 0.11, green: 0.133, blue: 0.29)
    static let bltTabPrimary = Color(red: 0.486, green: 0.361, blue: 1)
    static let bltTabCyan = Color(red: 0.133, green: 0.827, blue: 0.933)
    static let bltTabMuted = Color(red: 0.62, green: 0.66, blue: 0.82)
}
