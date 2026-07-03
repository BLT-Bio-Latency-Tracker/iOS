import SwiftUI

struct MainTabView: View {
    @State private var selectedTab: MainTab = .home
    @State private var isTabBarHidden = false
    @State private var isPVTMeasurementPresented = false
    @State private var isNotificationPresented = false
    @State private var isMyPagePresented = false
    @State private var pvtResultRefreshTrigger = 0
    @State private var pvtSubmissionErrorMessage: String?
    @State private var pvtDeletionErrorMessage: String?
    @State private var pendingPVTSubmission: PendingPVTSubmission?
    @State private var pendingDiscardedEvaluationID: Int?
    @State private var failedDiscardedEvaluationID: Int?
    @State private var isPVTSubmissionInFlight = false
    @StateObject private var latestSleepEvaluationSyncService = LatestSleepEvaluationSyncService()

    private let evaluationService = EvaluationService()
    var onWithdraw: () -> Void = {}
    var onLogout: () -> Void = {}

    var body: some View {
        ZStack {
            Color.bltTabBackground
                .ignoresSafeArea()

            selectedContent
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear
                        .frame(height: isTabBarHidden ? 0 : 76)
                }

            if !isTabBarHidden {
                VStack {
                    Spacer()

                    MainTabBar(selectedTab: $selectedTab)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 4)
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: selectedTab) { _, _ in
            if selectedTab == .home {
                updateTabBarVisibilityForHomeRoutes()
            } else {
                isNotificationPresented = false
                isMyPagePresented = false
                isTabBarHidden = false
            }
        }
        .onChange(of: isNotificationPresented) { _, _ in
            updateTabBarVisibilityForHomeRoutes()
        }
        .onChange(of: isMyPagePresented) { _, _ in
            updateTabBarVisibilityForHomeRoutes()
        }
        .onAppear {
            latestSleepEvaluationSyncService.start()
        }
        .fullScreenCover(isPresented: $isPVTMeasurementPresented) {
            PVTReadyView(
                onClose: {
                    pendingDiscardedEvaluationID = nil
                    isPVTMeasurementPresented = false
                },
                onComplete: { summary in
                    let measuredAt = Date()
                    let measurementId = UUID()
                    pendingPVTSubmission = PendingPVTSubmission(
                        summary: summary,
                        measuredAt: measuredAt,
                        measurementId: measurementId,
                        discardedEvaluationID: pendingDiscardedEvaluationID
                    )
                    pendingDiscardedEvaluationID = nil
                    submitPendingEvaluation()
                    selectedTab = .today
                    isPVTMeasurementPresented = false
                },
                onAbort: {
                    pendingDiscardedEvaluationID = nil
                    selectedTab = .home
                    isPVTMeasurementPresented = false
                }
            )
            .ignoresSafeArea()
        }
        .alert(
            "측정 결과 저장 실패",
            isPresented: Binding(
                get: { pvtSubmissionErrorMessage != nil },
                set: { if !$0 { pvtSubmissionErrorMessage = nil } }
            )
        ) {
            Button("다시 시도") {
                submitPendingEvaluation()
            }
            Button("확인", role: .cancel) {}
        } message: {
            Text(pvtSubmissionErrorMessage ?? "")
        }
        .alert(
            "기록 삭제 실패",
            isPresented: Binding(
                get: { pvtDeletionErrorMessage != nil },
                set: { if !$0 { pvtDeletionErrorMessage = nil } }
            )
        ) {
            Button("다시 시도") {
                retryDiscardedEvaluationDeletion()
            }
            Button("확인", role: .cancel) {}
        } message: {
            Text(pvtDeletionErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch selectedTab {
        case .today:
            TodayView(
                pvtResultRefreshTrigger: pvtResultRefreshTrigger,
                onSleepDetailVisibilityChanged: { isHidden in
                    isTabBarHidden = isHidden
                },
                onMeasureAgain: { action in
                    handleRemeasureAction(action)
                }
            )

        case .home:
            NavigationStack {
                HomeView(
                    onPVTStart: {
                        startPVTMeasurement()
                    },
                    onNotificationTap: {
                        openNotification()
                    },
                    onProfileTap: {
                        openMyPage()
                    }
                )
                .navigationDestination(isPresented: $isNotificationPresented) {
                    NotificationsView {
                        closeNotification()
                    }
                    .navigationBarBackButtonHidden(true)
                    .toolbar(.hidden, for: .navigationBar)
                }
                .navigationDestination(isPresented: $isMyPagePresented) {
                    MyPageView(
                        onBack: {
                            closeMyPage()
                        },
                        onWithdraw: {
                            closeMyPage()
                            onWithdraw()
                        },
                        onLogout: {
                            closeMyPage()
                            onLogout()
                        }
                    )
                    .navigationBarBackButtonHidden(true)
                    .toolbar(.hidden, for: .navigationBar)
                }
            }

        case .history:
            HistoryView { isHidden in
                isTabBarHidden = isHidden
            }
        }
    }

    private func openNotification() {
        isNotificationPresented = true
    }

    private func closeNotification() {
        isNotificationPresented = false
    }

    private func openMyPage() {
        isMyPagePresented = true
    }

    private func closeMyPage() {
        isMyPagePresented = false
    }

    private func updateTabBarVisibilityForHomeRoutes() {
        guard selectedTab == .home else { return }
        isTabBarHidden = isNotificationPresented || isMyPagePresented
    }

    private func handleRemeasureAction(_ action: TodayRemeasureAction) {
        switch action {
        case .startNewMeasurement, .saveCurrentAndRemeasure:
            pendingDiscardedEvaluationID = nil
            startPVTMeasurement()
        case .discardCurrentAndRemeasure:
            prepareDiscardAndStartMeasurement()
        }
    }

    private func startPVTMeasurement() {
        guard !isPVTSubmissionInFlight else {
            pvtSubmissionErrorMessage = "이전 측정 결과를 저장 중이에요. 저장이 끝난 뒤 다시 시도해주세요."
            return
        }
        isPVTMeasurementPresented = true
    }

    private func prepareDiscardAndStartMeasurement() {
        guard !isPVTSubmissionInFlight else {
            pvtSubmissionErrorMessage = "이전 측정 결과를 저장 중이에요. 저장이 끝난 뒤 다시 시도해주세요."
            return
        }

        Task {
            do {
#if DEBUG
                print("[PVT] Resolve latest evaluation for delayed discard")
#endif
                let latestMeasurement = try await evaluationService.fetchLatestPVTMeasurementForMeasurementDay()
                await MainActor.run {
#if DEBUG
                    print("[PVT] Resolve latest evaluation succeeded")
#endif
                    pendingDiscardedEvaluationID = latestMeasurement?.evaluationId
                    pvtDeletionErrorMessage = nil
                    startPVTMeasurement()
                }
            } catch {
                await MainActor.run {
#if DEBUG
                    print("[PVT] Resolve latest evaluation failed: \(error.localizedDescription)")
#endif
                    pvtDeletionErrorMessage = "폐기할 기존 기록을 확인하지 못했어요. 잠시 후 다시 시도해주세요."
                }
            }
        }
    }

    private func deleteDiscardedEvaluationIfNeeded(_ evaluationId: Int) {
        Task {
            do {
#if DEBUG
                print("[PVT] Delete discarded evaluation start")
#endif
                try await evaluationService.deleteEvaluation(id: evaluationId)
                await MainActor.run {
#if DEBUG
                    print("[PVT] Delete discarded evaluation succeeded")
#endif
                    failedDiscardedEvaluationID = nil
                    pvtDeletionErrorMessage = nil
                    pvtResultRefreshTrigger += 1
                }
            } catch {
                await MainActor.run {
#if DEBUG
                    print("[PVT] Delete discarded evaluation failed: \(error.localizedDescription)")
#endif
                    failedDiscardedEvaluationID = evaluationId
                    pvtDeletionErrorMessage = "새 측정은 저장됐지만 이전 기록 삭제에 실패했어요. 다시 시도해주세요."
                }
            }
        }
    }

    private func retryDiscardedEvaluationDeletion() {
        guard let failedDiscardedEvaluationID else {
            pvtDeletionErrorMessage = nil
            return
        }
        pvtDeletionErrorMessage = nil
        deleteDiscardedEvaluationIfNeeded(failedDiscardedEvaluationID)
    }

    private func submitPendingEvaluation() {
        guard let pendingPVTSubmission, !isPVTSubmissionInFlight else { return }
        isPVTSubmissionInFlight = true
        self.pendingPVTSubmission = nil
        pvtSubmissionErrorMessage = nil

        Task {
            do {
#if DEBUG
                print("[PVT] Submit evaluation start")
#endif
                let evaluation = try await evaluationService.submit(
                    summary: pendingPVTSubmission.summary,
                    measuredAt: pendingPVTSubmission.measuredAt,
                    measurementId: pendingPVTSubmission.measurementId
                )
                await MainActor.run {
#if DEBUG
                    print("[PVT] Submit evaluation succeeded")
#endif
                    PVTResultStore.shared.save(
                        pendingPVTSubmission.summary,
                        measuredAt: pendingPVTSubmission.measuredAt,
                        measurementId: pendingPVTSubmission.measurementId
                    )
                    EvaluationResultStore.shared.apply(evaluation)
                    if let discardedEvaluationID = pendingPVTSubmission.discardedEvaluationID {
                        deleteDiscardedEvaluationIfNeeded(discardedEvaluationID)
                    }
                    pvtSubmissionErrorMessage = nil
                    isPVTSubmissionInFlight = false
                    pvtResultRefreshTrigger += 1
                    if self.pendingPVTSubmission != nil {
                        submitPendingEvaluation()
                    }
                }
            } catch {
                await MainActor.run {
#if DEBUG
                    print("[PVT] Submit evaluation failed")
#endif
                    self.pendingPVTSubmission = pendingPVTSubmission
                    pvtSubmissionErrorMessage = error.localizedDescription
                    isPVTSubmissionInFlight = false
                }
            }
        }
    }
}

private struct PendingPVTSubmission {
    let summary: PVTSummary
    let measuredAt: Date
    let measurementId: UUID
    let discardedEvaluationID: Int?
}

private struct MainTabBar: View {
    @Binding var selectedTab: MainTab
    @GestureState private var isPressing = false
    @State private var pulsingTab: MainTab?

    var body: some View {
        GeometryReader { proxy in
            let itemWidth = proxy.size.width / CGFloat(MainTab.allCases.count)
            let selectedIndex = CGFloat(MainTab.allCases.firstIndex(of: selectedTab) ?? 0)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.bltTabPrimary, Color.bltTabCyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: Color.bltTabPrimary.opacity(0.28), radius: 14, x: 0, y: 8)
                    .frame(width: itemWidth, height: 46)
                    .offset(x: itemWidth * selectedIndex)
                    .animation(.spring(response: 0.34, dampingFraction: 0.82), value: selectedTab)

                HStack(spacing: 0) {
                    ForEach(MainTab.allCases) { tab in
                        Button {
                            withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                                selectedTab = tab
                            }
                            triggerPulse(for: tab)
                        } label: {
                            MainTabItem(
                                tab: tab,
                                isSelected: selectedTab == tab,
                                isPulsing: pulsingTab == tab
                            )
                            .frame(width: itemWidth)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(tab.title))
                        .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(height: 60)
        .modifier(MainTabBarBackground())
        .compositingGroup()
        .scaleEffect(isPressing ? 1.018 : 1)
        .animation(.spring(response: 0.18, dampingFraction: 0.78), value: isPressing)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isPressing) { _, state, _ in
                    state = true
                }
        )
    }

    private func triggerPulse(for tab: MainTab) {
        pulsingTab = tab

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            guard pulsingTab == tab else { return }
            pulsingTab = nil
        }
    }
}

private struct MainTabItem: View {
    let tab: MainTab
    let isSelected: Bool
    let isPulsing: Bool

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: isSelected ? tab.selectedSystemImage : tab.systemImage)
                .font(.system(size: tab == .home ? 19 : 17, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 30, height: 23)
                .scaleEffect(isPulsing ? 1.16 : 1)

            Text(tab.title)
                .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                .lineLimit(1)
                .scaleEffect(isPulsing ? 1.05 : 1)
        }
        .foregroundStyle(isSelected ? Color.white : Color.bltTabMuted)
        .frame(height: 46)
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.2, dampingFraction: 0.62), value: isPulsing)
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
                                .tint(Color.bltTabCard.opacity(0.68)),
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
