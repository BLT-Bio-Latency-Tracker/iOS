import Combine
import SwiftUI

struct TodayView: View {
    @StateObject private var viewModel = TodayViewModel()
    @State private var isSleepDetailPresented = false
    @State private var isPVTDetailPresented = false
    @State private var isRemeasureSheetPresented = false

    var pvtResultRefreshTrigger = 0
    var onSleepDetailVisibilityChanged: (Bool) -> Void = { _ in }
    var onMeasureAgain: (TodayRemeasureAction) -> Void = { _ in }

    private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private let designWidth: CGFloat = 390
    private let designHeight: CGFloat = 844

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let scale = proxy.size.width / designWidth
                let contentWidth = max(0, proxy.size.width - 40 * scale)
                let horizontalInset = (proxy.size.width - contentWidth) / 2
                let topPadding = max(36 * scale, 60 * scale - proxy.safeAreaInsets.top)

                ZStack {
                    Color.todayBackground
                        .ignoresSafeArea()

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            Text("오늘의 결과")
                                .font(.system(size: 16 * scale, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.top, topPadding)

                            roiIndexCard(scale: scale)
                                .padding(.top, 25 * scale)

                            if viewModel.state.hasROIResult {
                                comparisonNotice(scale: scale)
                                    .padding(.top, 16 * scale)
                            } else {
                                pvtMissingNotice(scale: scale)
                                    .padding(.top, 16 * scale)
                            }

                            comparisonPicker(scale: scale)
                                .padding(.top, 18 * scale)
                                .padding(.horizontal, 11 * scale)

                            if let sleep = viewModel.state.sleep {
                                sleepConnectedCard(sleep, scale: scale)
                                    .padding(.top, 20 * scale)
                            } else if viewModel.state.sleepStatus == .notConnected {
                                sleepDisconnectedCard(scale: scale)
                                    .padding(.top, 20 * scale)
                            } else {
                                sleepUnavailableCard(scale: scale)
                                    .padding(.top, 20 * scale)
                            }

                            pvtCard(scale: scale)
                                .padding(.top, 9 * scale)

                            measureAgainButton(scale: scale)
                                .padding(.top, 24 * scale)
                                .padding(.bottom, 36 * scale)
                        }
                        .padding(.horizontal, horizontalInset)
                    }
                    .refreshable {
                        viewModel.refreshPVTResult()
                        await viewModel.loadHealthKitSleepSummary()
                    }

                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .navigationDestination(isPresented: $isSleepDetailPresented) {
                if let sleep = viewModel.state.sleep {
                    SleepDetailView(sleep: sleep) {
                        isSleepDetailPresented = false
                    }
                    .navigationBarBackButtonHidden(true)
                    .toolbar(.hidden, for: .navigationBar)
                }
            }
            .navigationDestination(isPresented: $isPVTDetailPresented) {
                PVTDetailView {
                    isPVTDetailPresented = false
                }
                .navigationBarBackButtonHidden(true)
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        .preferredColorScheme(.dark)
        .task(id: pvtResultRefreshTrigger) {
            viewModel.refreshPVTResult()
            await viewModel.loadHealthKitSleepSummary()
        }
        .onAppear {
            viewModel.refreshPVTResult()
        }
        .onReceive(refreshTimer) { _ in
            viewModel.refreshPVTResult()
        }
        .onChange(of: isSleepDetailPresented) { _, _ in
            notifyDetailVisibilityChanged()
        }
        .onChange(of: isPVTDetailPresented) { _, _ in
            notifyDetailVisibilityChanged()
        }
        .onChange(of: isRemeasureSheetPresented) { _, _ in
            notifyDetailVisibilityChanged()
        }
        .sheet(isPresented: $isRemeasureSheetPresented) {
            GeometryReader { proxy in
                let scale = min(proxy.size.width / designWidth, 1.08)

                remeasureConfirmationSheet(scale: scale)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }
            .presentationDetents([.height(378)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(Color.todayCard)
            .preferredColorScheme(.dark)
        }
    }

    private func roiIndexCard(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(viewModel.roiIndexTitle)
                .font(.system(size: 9.5 * scale, weight: .semibold))
                .tracking(1.5 * scale)
                .foregroundStyle(viewModel.state.isSleepDataConnected ? .white.opacity(0.55) : Color.todayCaution)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            HStack(alignment: .center, spacing: 20 * scale) {
                Text(viewModel.roiScoreText)
                    .font(.system(size: 54 * scale, weight: .heavy))
                    .foregroundStyle(viewModel.state.hasROIResult ? .white : Color.todayMutedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .frame(width: (viewModel.state.hasROIResult ? 78 : 132) * scale, alignment: .leading)

                if viewModel.state.hasROIResult {
                    roiChangeBadge(scale: scale)
                        .padding(.top, 7 * scale)
                }

                Spacer()
            }
            .padding(.top, 2 * scale)

            Text(viewModel.roiFooterText)
                .font(.system(size: 11 * scale, weight: .medium))
                .foregroundStyle(viewModel.state.isSleepDataConnected ? .white.opacity(0.85) : Color.todayMutedText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.top, viewModel.state.isSleepDataConnected ? 0 : 2 * scale)
        }
        .padding(.horizontal, 16 * scale)
        .padding(.top, 9 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 120 * scale)
        .background {
            LinearGradient(
                colors: [
                    Color.todayPrimary.opacity(0.32),
                    Color.todayCyan.opacity(0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 22 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22 * scale, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        }
    }

    private func roiChangeBadge(scale: CGFloat) -> some View {
        let changeColor = roiChangeColor(for: viewModel.roiChangeDirection)

        return Text(viewModel.roiChangeText)
            .font(.system(size: 11 * scale, weight: .bold))
            .foregroundStyle(changeColor)
            .frame(width: 76 * scale, height: 22 * scale)
            .background(changeColor.opacity(0.18))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(changeColor.opacity(0.4), lineWidth: 1)
            }
    }

    private func comparisonNotice(scale: CGFloat) -> some View {
        let isPositive = viewModel.state.sleepStatus == .available
        let foregroundColor = comparisonNoticeForeground
        let backgroundColor = comparisonNoticeBackground

        return HStack(spacing: isPositive ? 0 : 8 * scale) {
            comparisonNoticeIcon(scale: scale)

            VStack(alignment: .leading, spacing: 6 * scale) {
                Text(viewModel.comparisonSummaryTitle)
                    .font(.system(size: isPositive ? 13 * scale : 11 * scale, weight: isPositive ? .semibold : .medium))
                    .foregroundStyle(foregroundColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if let subtitle = viewModel.comparisonSummarySubtitle {
                    Text(subtitle)
                        .font(.system(size: 11 * scale, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, isPositive ? 16 * scale : 14 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: isPositive ? 56 * scale : 44 * scale)
        .background(backgroundColor.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12 * scale, style: .continuous)
                .stroke(backgroundColor.opacity(isPositive ? 0.35 : 0.5), lineWidth: 1)
        }
    }

    private func pvtMissingNotice(scale: CGFloat) -> some View {
        HStack(spacing: 8 * scale) {
            Text("⚠")
                .font(.system(size: 14 * scale, weight: .regular))
                .foregroundStyle(Color.todayCaution)
                .frame(width: 22 * scale)

            Text("PVT 측정값이 없어 ROI 점수를 측정할 수 없어요")
                .font(.system(size: 11 * scale, weight: .medium))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 15 * scale)
        .frame(width: 326 * scale, height: 40 * scale, alignment: .leading)
        .background(Color.todayCaution.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12 * scale, style: .continuous)
                .stroke(Color.todayCaution.opacity(0.5), lineWidth: 1)
        }
    }

    @ViewBuilder
    private func comparisonNoticeIcon(scale: CGFloat) -> some View {
        if viewModel.state.sleepStatus != .available {
            Text(comparisonNoticeIconText)
                .font(.system(size: 14 * scale, weight: .regular))
                .foregroundStyle(comparisonNoticeForeground)
                .frame(width: 22 * scale)
        }
    }

    private func comparisonPicker(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 9 * scale) {
            Text("비교 기준")
                .font(.system(size: 11 * scale, weight: .semibold))
                .tracking(0.4 * scale)
                .foregroundStyle(Color.todayMutedText)

            HStack(spacing: 0) {
                ForEach(TodayComparisonType.allCases) { type in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
                            viewModel.selectedComparison = type
                        }
                    } label: {
                        Text(verbatim: type.title)
                            .font(.system(size: 12 * scale, weight: viewModel.selectedComparison == type ? .semibold : .regular))
                            .foregroundStyle(viewModel.selectedComparison == type ? .white : Color.todayMutedText)
                            .id("today-comparison-\(type.id)")
                            .transaction { transaction in
                                transaction.animation = nil
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 32 * scale)
                            .background {
                                if viewModel.selectedComparison == type {
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.todayPrimary, Color.todayCyan],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4 * scale)
            .frame(height: 40 * scale)
            .background(Color.todayCard)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.todayBorder, lineWidth: 1)
            }
        }
    }

    private func sleepConnectedCard(_ sleep: TodaySleepData, scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("🛌  수면 데이터")
                    .font(.system(size: 11 * scale, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))

                Spacer()

                Button {
                    isSleepDetailPresented = true
                } label: {
                    HStack(spacing: 2 * scale) {
                        Text("상세 분석")
                        Text("›")
                    }
                    .font(.system(size: 12 * scale, weight: .medium))
                    .foregroundStyle(Color.todayCyan)
                }
                .buttonStyle(.plain)
            }

            HStack(alignment: .bottom, spacing: 10 * scale) {
                Text(sleep.totalSleepText)
                    .font(.system(size: 28 * scale, weight: .heavy))
                    .foregroundStyle(.white)

                if let differenceText = sleep.differenceText {
                    Text(differenceText)
                        .font(.system(size: 10 * scale, weight: .bold))
                        .foregroundStyle(sleepDifferenceForeground(for: sleep.differenceDirection))
                        .padding(.horizontal, 7 * scale)
                        .frame(height: 20 * scale)
                        .background(sleepDifferenceBackground(for: sleep.differenceDirection))
                        .clipShape(Capsule())
                        .offset(y: -4 * scale)
                }
            }
            .padding(.top, 10 * scale)

            SleepStageBar(stages: sleep.stages, scale: scale)
                .frame(height: 7 * scale)
                .padding(.top, 12 * scale)
        }
        .padding(.horizontal, 16 * scale)
        .padding(.top, 11 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 112 * scale)
        .background(Color.todayCard)
        .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func sleepDisconnectedCard(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4 * scale) {
                Text("🌙")
                    .font(.system(size: 15 * scale))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 24 * scale, alignment: .leading)

                Text("수면 데이터")
                    .font(.system(size: 12 * scale, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                Text("🔒 미연동")
                    .font(.system(size: 10 * scale, weight: .semibold))
                    .foregroundStyle(Color.todayMutedText)
                    .frame(width: 60 * scale, height: 22 * scale)
                    .background(Color.todayBorder)
                    .clipShape(Capsule())
            }

            Text("수면 데이터를 연동하면 전체 점수와\n수면 단계 분석을 확인할 수 있어요")
                .font(.system(size: 11 * scale, weight: .regular))
                .foregroundStyle(Color.todayMutedText)
                .lineSpacing(2 * scale)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 11 * scale)

            Button {
                Task {
                    await viewModel.connectHealthKit()
                }
            } label: {
                Text(viewModel.isRequestingHealthKitAuthorization ? "요청 중" : "HealthKit 연동하기")
                    .font(.system(size: 11 * scale, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 30 * scale)
                    .background(
                        LinearGradient(
                            colors: [Color.todayPrimary, Color.todayCyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8 * scale, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isRequestingHealthKitAuthorization)
            .opacity(viewModel.isRequestingHealthKitAuthorization ? 0.7 : 1)
            .padding(.top, 9 * scale)
        }
        .padding(.horizontal, 16 * scale)
        .padding(.top, 6 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 120 * scale)
        .background(Color.todayCard)
        .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                .stroke(Color.todayPrimary.opacity(0.5), lineWidth: 1.5)
        }
    }

    private func sleepUnavailableCard(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4 * scale) {
                Text("🌙")
                    .font(.system(size: 15 * scale))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 24 * scale, alignment: .leading)

                Text("수면 데이터")
                    .font(.system(size: 12 * scale, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))

                Spacer()

                Text(sleepStatusBadgeText)
                    .font(.system(size: 10 * scale, weight: .semibold))
                    .foregroundStyle(comparisonNoticeForeground)
                    .frame(width: 76 * scale, height: 22 * scale)
                    .background(comparisonNoticeBackground.opacity(0.14))
                    .clipShape(Capsule())
            }

            Text(sleepUnavailableMessage)
                .font(.system(size: 11 * scale, weight: .regular))
                .foregroundStyle(Color.todayMutedText)
                .lineSpacing(2 * scale)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12 * scale)
        }
        .padding(.horizontal, 16 * scale)
        .padding(.top, 12 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 92 * scale)
        .background(Color.todayCard)
        .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                .stroke(comparisonNoticeBackground.opacity(0.45), lineWidth: 1.2)
        }
    }

    private func pvtCard(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 8 * scale) {
                    Text("⚡")
                        .font(.system(size: 15 * scale))

                    Text("PVT 검사")
                        .font(.system(size: 12 * scale, weight: .semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                if viewModel.state.hasTodayPVTData {
                    Button {
                        isPVTDetailPresented = true
                    } label: {
                        HStack(spacing: 2 * scale) {
                            Text("상세 분석")
                            Text("›")
                        }
                        .font(.system(size: 12 * scale, weight: .medium))
                        .foregroundStyle(Color.todayCyan)
                    }
                    .buttonStyle(.plain)
                }
            }

            if viewModel.state.hasTodayPVTData {
                HStack(alignment: .lastTextBaseline, spacing: 10 * scale) {
                    Text(String(viewModel.state.pvt.averageMs))
                        .font(.system(size: 28 * scale, weight: .bold))
                        .foregroundStyle(.white)

                    Text("ms 평균")
                        .font(.system(size: 11 * scale, weight: .regular))
                        .foregroundStyle(Color.todayMutedText)
                        .padding(.bottom, 4 * scale)

                    Spacer()

                    if let changeText = viewModel.state.pvt.changeText {
                        Text(changeText)
                            .font(.system(size: 10 * scale, weight: .bold))
                            .foregroundStyle(Color.todayPositive)
                            .padding(.horizontal, 8 * scale)
                            .frame(height: 20 * scale)
                            .background(Color.todayPositive.opacity(0.18))
                            .clipShape(Capsule())
                    }

                    if let highlightText = viewModel.state.pvt.highlightText {
                        Text(highlightText)
                            .font(.system(size: 9 * scale, weight: .semibold))
                            .foregroundStyle(Color.todayCyan)
                            .padding(.horizontal, 10 * scale)
                            .frame(height: 20 * scale)
                            .background(Color.todayCyan.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(Color.todayCyan.opacity(0.85), lineWidth: 1)
                            }
                        }
                }
                .padding(.top, 10 * scale)

                PVTTrialBar(trials: viewModel.state.pvt.trials, scale: scale)
                    .frame(height: 16 * scale)
                    .padding(.top, 10 * scale)
            } else {
                VStack(alignment: .leading, spacing: 6 * scale) {
                    Text("오늘 PVT 측정 데이터가 없어요")
                        .font(.system(size: 18 * scale, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text("측정하기로 오늘의 반응 속도를 기록하세요")
                        .font(.system(size: 11 * scale, weight: .medium))
                        .foregroundStyle(Color.todayMutedText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(.top, 18 * scale)
            }
        }
        .padding(.horizontal, 16 * scale)
        .padding(.top, 10 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 112 * scale)
        .background(Color.todayCard)
        .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                .stroke(Color.todayBorder, lineWidth: 1)
        }
    }

    private func measureAgainButton(scale: CGFloat) -> some View {
        Button {
            if viewModel.state.hasTodayPVTData {
                isRemeasureSheetPresented = true
            } else {
                onMeasureAgain(.startNewMeasurement)
            }
        } label: {
            Text(viewModel.state.hasTodayPVTData ? "다시 측정하기" : "측정하기")
                .font(.system(size: 16 * scale, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50 * scale)
                .background(
                    LinearGradient(
                        colors: [Color.todayPrimary, Color.todayCyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func remeasureConfirmationSheet(scale: CGFloat) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color.todayPrimary.opacity(0.18))
                    .frame(width: 64 * scale, height: 64 * scale)

                Text("🔄")
                    .font(.system(size: 31 * scale, weight: .regular))
                    .frame(width: 38 * scale, height: 38 * scale)
            }
            .padding(.top, 34 * scale)

            Text("다시 측정할까요?")
                .font(.system(size: 19 * scale, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(.top, 14 * scale)

            Text("방금 측정한 기록을 어떻게 처리할까요?")
                .font(.system(size: 14 * scale, weight: .regular))
                .foregroundStyle(.white.opacity(0.6))
                .frame(maxWidth: .infinity)
                .padding(.top, 8 * scale)

            Button {
                handleRemeasureAction(.saveCurrentAndRemeasure)
            } label: {
                Text("기록 유지 후 재측정")
                    .font(.system(size: 15 * scale, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52 * scale)
                    .background(
                        LinearGradient(
                            colors: [Color.todayPrimary, Color.todayCyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24 * scale)
            .padding(.top, 18 * scale)

            Button {
                handleRemeasureAction(.discardCurrentAndRemeasure)
            } label: {
                Text("기록 폐기 후 재측정")
                    .font(.system(size: 15 * scale, weight: .semibold))
                    .foregroundStyle(Color.todayRemeasureDangerText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52 * scale)
                    .background(Color.todayRemeasureDanger.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                            .stroke(Color.todayRemeasureDanger.opacity(0.5), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24 * scale)
            .padding(.top, 10 * scale)

            Button {
                dismissRemeasureSheet()
            } label: {
                Text("취소")
                    .font(.system(size: 14 * scale, weight: .regular))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .frame(height: 30 * scale)
            }
            .buttonStyle(.plain)
            .padding(.top, 18 * scale)
        }
        .frame(maxWidth: .infinity)
        .background(Color.todayCard)
    }

    private func handleRemeasureAction(_ action: TodayRemeasureAction) {
        dismissRemeasureSheet()
        onMeasureAgain(action)
    }

    private func dismissRemeasureSheet() {
        isRemeasureSheetPresented = false
    }

    private func sleepDifferenceForeground(for direction: TodaySleepDifferenceDirection?) -> Color {
        switch direction {
        case .positive:
            return Color.todayPositive
        case .negative:
            return Color.todayNegative
        case .neutral, .none:
            return Color.todayMutedText
        }
    }

    private func sleepDifferenceBackground(for direction: TodaySleepDifferenceDirection?) -> Color {
        sleepDifferenceForeground(for: direction).opacity(0.18)
    }

    private func notifyDetailVisibilityChanged() {
        onSleepDetailVisibilityChanged(
            isSleepDetailPresented || isPVTDetailPresented || isRemeasureSheetPresented
        )
    }

    private var comparisonNoticeIconText: String {
        switch viewModel.state.sleepStatus {
        case .available:
            return ""
        case .notConnected, .noWearableData:
            return "⚠"
        case .syncing:
            return "⏳"
        case .noSleep:
            return "🌙"
        }
    }

    private var comparisonNoticeForeground: Color {
        switch viewModel.state.sleepStatus {
        case .available:
            switch viewModel.roiChangeDirection {
            case .positive:
                return Color.todayPositive
            case .negative:
                return Color.todayNegative
            case .neutral:
                return Color.todayMutedText
            }
        case .syncing:
            return Color.todayCyan
        case .noSleep, .notConnected, .noWearableData:
            return Color.todayCaution
        }
    }

    private var comparisonNoticeBackground: Color {
        comparisonNoticeForeground
    }

    private func roiChangeColor(for direction: TodayROIChangeDirection) -> Color {
        switch direction {
        case .positive:
            return Color.todayPositive
        case .negative:
            return Color.todayNegative
        case .neutral:
            return Color.todayMutedText
        }
    }

    private var sleepStatusBadgeText: String {
        switch viewModel.state.sleepStatus {
        case .syncing:
            return "동기화 대기"
        case .noWearableData:
            return "기록 없음"
        case .available, .notConnected, .noSleep:
            return ""
        }
    }

    private var sleepUnavailableMessage: String {
        switch viewModel.state.sleepStatus {
        case .syncing:
            return "HealthKit에 오늘 수면 데이터가 아직 반영되지 않았어요.\n잠시 후 아래로 당겨 새로고침해보세요."
        case .noWearableData:
            return "오늘 수면 기록이 없어요.\nApple Watch 착용 또는 수면 집중모드 기록을 확인해주세요."
        case .available, .notConnected, .noSleep:
            return ""
        }
    }
}

private struct SleepStageBar: View {
    let stages: [TodaySleepStage]
    let scale: CGFloat

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                ForEach(stages) { stage in
                    color(for: stage.kind)
                        .frame(width: max(proxy.size.width * stage.ratio, 1))
                        .offset(x: proxy.size.width * stage.startRatio)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
            .background(.white.opacity(0.08))
            .clipShape(Capsule())
        }
    }

    private func color(for kind: TodaySleepStageKind) -> Color {
        switch kind {
        case .core:
            return Color.todayCyan.opacity(0.72)
        case .deep:
            return Color.todayPrimary
        case .rem:
            return Color.todaySleepRem
        case .awake:
            return Color.todayNegative
        }
    }

}

private struct PVTTrialBar: View {
    let trials: [Int]
    let scale: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let bestValue = trials.min()
            let itemCount = CGFloat(max(trials.count, 1))
            let barWidth = min(24 * scale, proxy.size.width / (itemCount * 1.8))
            let spacing = itemCount > 1
                ? max(8 * scale, (proxy.size.width - (barWidth * itemCount)) / (itemCount - 1))
                : 0

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(trials.enumerated()), id: \.offset) { _, value in
                    let maximumMilliseconds: CGFloat = 500
                    let clampedValue = min(max(CGFloat(value), 0), maximumMilliseconds)
                    let heightRatio = clampedValue / maximumMilliseconds

                    RoundedRectangle(cornerRadius: 3 * scale, style: .continuous)
                        .fill(value == bestValue ? Color.todayCyan : Color.todayPVTBar)
                        .frame(width: barWidth, height: max(4 * scale, proxy.size.height * heightRatio))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottomLeading)
        }
    }
}

private extension Color {
    static let todayBackground = Color(red: 0.039, green: 0.055, blue: 0.153)
    static let todayCard = Color(red: 0.078, green: 0.098, blue: 0.216)
    static let todayBorder = Color(red: 0.11, green: 0.133, blue: 0.29)
    static let todayPrimary = Color(red: 0.486, green: 0.361, blue: 1)
    static let todayCyan = Color(red: 0.133, green: 0.827, blue: 0.933)
    static let todayPositive = Color(red: 0.063, green: 0.725, blue: 0.506)
    static let todayNegative = Color(red: 0.937, green: 0.267, blue: 0.267)
    static let todayCaution = Color(red: 0.961, green: 0.62, blue: 0.043)
    static let todayMutedText = Color(red: 0.62, green: 0.66, blue: 0.82)
    static let todayPVTBar = Color(red: 0.42, green: 0.46, blue: 0.62).opacity(0.6)
    static let todaySleepRem = Color(red: 0.83, green: 0.56, blue: 0.02)
    static let todayRemeasureDanger = Color(red: 1, green: 0.31, blue: 0.31)
    static let todayRemeasureDangerText = Color(red: 1, green: 0.31, blue: 0.31).opacity(0.9)
}

enum TodayRemeasureAction {
    case startNewMeasurement
    case saveCurrentAndRemeasure
    case discardCurrentAndRemeasure
}
