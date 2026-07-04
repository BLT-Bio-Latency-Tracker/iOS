import SwiftUI

struct HistoryCompareTodayView: View {
    let state: HistoryDayDetailState
    let onClose: () -> Void

    @StateObject private var todayViewModel: HistoryDayDetailViewModel

    private let designWidth: CGFloat = 390

    init(state: HistoryDayDetailState, onClose: @escaping () -> Void) {
        self.state = state
        self.onClose = onClose
        _todayViewModel = StateObject(wrappedValue: HistoryDayDetailViewModel(date: Date()))
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / designWidth
            let contentWidth = max(0, proxy.size.width - 36 * scale)
            let horizontalInset = (proxy.size.width - contentWidth) / 2
            let topPadding = max(0, 38 * scale - proxy.safeAreaInsets.top)

            ZStack {
                Color.compareBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header(scale: scale)
                        .padding(.top, topPadding)
                        .padding(.horizontal, horizontalInset)
                        .padding(.bottom, 18 * scale)
                        .background(Color.compareBackground)
                        .zIndex(1)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            if todayViewModel.state.isLoading {
                                loadingState(scale: scale)
                                    .padding(.top, 190 * scale)
                            } else {
                                roiCard(scale: scale)

                                sleepCard(scale: scale)
                                    .padding(.top, 12 * scale)

                                pvtCard(scale: scale)
                                    .padding(.top, 12 * scale)

                                insightCard(scale: scale)
                                    .padding(.top, 12 * scale)
                            }
                        }
                        .padding(.horizontal, horizontalInset)
                        .padding(.bottom, 34 * scale)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await todayViewModel.loadIfNeeded()
        }
        .enablesInteractivePopGesture()
    }

    private func header(scale: CGFloat) -> some View {
        ZStack {
            VStack(spacing: 2 * scale) {
                Text("오늘과 비교")
                    .font(.system(size: 17 * scale, weight: .semibold))
                    .foregroundStyle(.white)

                Text("\(headerDateText(state.selectedDate)) ↔ 오늘")
                    .font(.system(size: 11 * scale, weight: .regular))
                    .foregroundStyle(Color.compareMuted)
            }
            .frame(maxWidth: .infinity)

            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18 * scale, weight: .regular))
                        .foregroundStyle(.white.opacity(0.88))
                        .frame(width: 42 * scale, height: 42 * scale)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("닫기")

                Spacer()
            }
        }
        .frame(height: 48 * scale)
    }

    private func roiCard(scale: CGFloat) -> some View {
        card(scale: scale) {
            VStack(alignment: .leading, spacing: 0) {
                cardCaption("BRAIN ROI INDEX", scale: scale)

                HStack(alignment: .center, spacing: 0) {
                    roiColumn(
                        title: shortDateText(state.selectedDate),
                        score: selectedMetrics.roi,
                        isToday: false,
                        scale: scale
                    )

                    deltaChipView(
                        delta(selected: selectedMetrics.roi, today: todayMetrics.roi, higherIsBetter: true) {
                            String($0)
                        },
                        scale: scale
                    )
                    .frame(width: 64 * scale)

                    roiColumn(
                        title: "오늘",
                        score: todayMetrics.roi,
                        isToday: true,
                        scale: scale
                    )
                }
                .padding(.top, 14 * scale)
            }
        }
    }

    private func roiColumn(title: String, score: Int?, isToday: Bool, scale: CGFloat) -> some View {
        VStack(spacing: 3 * scale) {
            Text(title)
                .font(.system(size: 11 * scale, weight: isToday ? .semibold : .regular))
                .foregroundStyle(isToday ? Color.compareAccent : Color.compareMuted)

            Text(score.map(String.init) ?? "--")
                .font(.system(size: 34 * scale, weight: .heavy))
                .foregroundStyle(isToday ? .white : Color.compareText)

            Text(score.map(roiStatusTitle) ?? "측정 전")
                .font(.system(size: 11 * scale, weight: .regular))
                .foregroundStyle(Color.compareMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func sleepCard(scale: CGFloat) -> some View {
        card(scale: scale) {
            VStack(alignment: .leading, spacing: 0) {
                cardCaption("수면", scale: scale)

                if selectedMetrics.sleep == nil, todayMetrics.sleep == nil {
                    Text("표시할 수면 데이터가 없어요")
                        .font(.system(size: 12 * scale, weight: .regular))
                        .foregroundStyle(Color.compareMuted)
                        .padding(.top, 12 * scale)
                } else {
                    sleepTimelineRow(
                        title: shortDateText(state.selectedDate),
                        sleep: selectedMetrics.sleep,
                        isToday: false,
                        scale: scale
                    )
                    .padding(.top, 14 * scale)

                    sleepTimelineRow(
                        title: "오늘",
                        sleep: todayMetrics.sleep,
                        isToday: true,
                        scale: scale
                    )
                    .padding(.top, 8 * scale)

                    sleepLegend(scale: scale)
                        .padding(.top, 10 * scale)

                    columnHeaderRow(scale: scale)
                        .padding(.top, 12 * scale)

                    metricRow(
                        title: "총 수면",
                        left: selectedMetrics.sleep.map { durationText($0.totalMinutes) },
                        right: todayMetrics.sleep.map { durationText($0.totalMinutes) },
                        delta: delta(
                            selected: selectedMetrics.sleep?.totalMinutes,
                            today: todayMetrics.sleep?.totalMinutes,
                            higherIsBetter: true,
                            format: durationText
                        ),
                        scale: scale
                    )

                    metricRow(
                        title: "수면 효율",
                        left: selectedMetrics.sleep?.efficiencyPercent.map { "\($0)%" },
                        right: todayMetrics.sleep?.efficiencyPercent.map { "\($0)%" },
                        delta: delta(
                            selected: selectedMetrics.sleep?.efficiencyPercent,
                            today: todayMetrics.sleep?.efficiencyPercent,
                            higherIsBetter: true
                        ) { "\($0)%" },
                        scale: scale
                    )

                    metricRow(
                        title: "깊은 수면",
                        left: selectedMetrics.sleep.map { durationText($0.deepMinutes) },
                        right: todayMetrics.sleep.map { durationText($0.deepMinutes) },
                        delta: delta(
                            selected: selectedMetrics.sleep?.deepMinutes,
                            today: todayMetrics.sleep?.deepMinutes,
                            higherIsBetter: true,
                            format: durationText
                        ),
                        scale: scale
                    )

                    metricRow(
                        title: "심박 변이도",
                        left: selectedMetrics.nightHrvMs.map { "\($0)ms" },
                        right: todayMetrics.nightHrvMs.map { "\($0)ms" },
                        delta: delta(
                            selected: selectedMetrics.nightHrvMs,
                            today: todayMetrics.nightHrvMs,
                            higherIsBetter: true
                        ) { "\($0)ms" },
                        scale: scale
                    )
                }
            }
        }
    }

    private func sleepTimelineRow(
        title: String,
        sleep: HistoryDaySleepSummary?,
        isToday: Bool,
        scale: CGFloat
    ) -> some View {
        HStack(spacing: 8 * scale) {
            Text(title)
                .font(.system(size: 11 * scale, weight: isToday ? .semibold : .regular))
                .foregroundStyle(isToday ? Color.compareAccent : Color.compareMuted)
                .frame(width: 34 * scale, alignment: .leading)

            if let sleep, !sleep.stageSegments.isEmpty {
                HistorySleepStageTimelineBar(segments: sleep.stageSegments, height: 10 * scale)
            } else {
                Capsule()
                    .fill(.white.opacity(0.08))
                    .frame(height: 10 * scale)
                    .overlay {
                        Text("데이터 없음")
                            .font(.system(size: 9 * scale, weight: .regular))
                            .foregroundStyle(Color.compareMuted)
                    }
            }
        }
    }

    private func sleepLegend(scale: CGFloat) -> some View {
        HStack(spacing: 12 * scale) {
            legendItem("얕은", color: HistoryDaySleepStageKind.core.color, scale: scale)
            legendItem("깊은", color: HistoryDaySleepStageKind.deep.color, scale: scale)
            legendItem("REM", color: HistoryDaySleepStageKind.rem.color, scale: scale)
            legendItem("비수면", color: HistoryDaySleepStageKind.awake.color, scale: scale)
        }
        .padding(.leading, 42 * scale)
    }

    private func legendItem(_ title: String, color: Color, scale: CGFloat) -> some View {
        HStack(spacing: 4 * scale) {
            Circle()
                .fill(color)
                .frame(width: 7 * scale, height: 7 * scale)

            Text(title)
                .font(.system(size: 10 * scale, weight: .regular))
                .foregroundStyle(Color.compareMuted)
        }
    }

    private func pvtCard(scale: CGFloat) -> some View {
        card(scale: scale) {
            VStack(alignment: .leading, spacing: 0) {
                cardCaption("PVT 평균", scale: scale)

                columnHeaderRow(scale: scale)
                    .padding(.top, 12 * scale)

                metricRow(
                    title: "평균 반응",
                    left: selectedMetrics.averageReactionMs.map { "\($0)ms" },
                    right: todayMetrics.averageReactionMs.map { "\($0)ms" },
                    delta: delta(
                        selected: selectedMetrics.averageReactionMs,
                        today: todayMetrics.averageReactionMs,
                        higherIsBetter: false
                    ) { "\($0)ms" },
                    scale: scale
                )

                metricRow(
                    title: "Lapse",
                    left: selectedMetrics.averageLapse.map { "\($0)회" },
                    right: todayMetrics.averageLapse.map { "\($0)회" },
                    delta: delta(
                        selected: selectedMetrics.averageLapse,
                        today: todayMetrics.averageLapse,
                        higherIsBetter: false
                    ) { "\($0)회" },
                    scale: scale
                )

                metricRow(
                    title: "False Start",
                    left: selectedMetrics.averageFalseStart.map { "\($0)회" },
                    right: todayMetrics.averageFalseStart.map { "\($0)회" },
                    delta: delta(
                        selected: selectedMetrics.averageFalseStart,
                        today: todayMetrics.averageFalseStart,
                        higherIsBetter: false
                    ) { "\($0)회" },
                    scale: scale
                )

                metricRow(
                    title: "측정 횟수",
                    left: "\(selectedMetrics.pvtCount)회",
                    right: todayMetrics.pvtCount > 0 ? "\(todayMetrics.pvtCount)회" : nil,
                    delta: nil,
                    scale: scale
                )
            }
        }
    }

    private func insightCard(scale: CGFloat) -> some View {
        let insight = compareInsight

        return VStack(alignment: .leading, spacing: 10 * scale) {
            Text(insight.title)
                .font(.system(size: 13 * scale, weight: .semibold))
                .foregroundStyle(Color.compareAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(insight.message)
                .font(.system(size: 11 * scale, weight: .regular))
                .foregroundStyle(.white.opacity(0.65))
                .lineSpacing(3 * scale)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.compareAccent.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14 * scale, style: .continuous)
                .stroke(Color.compareAccent.opacity(0.3), lineWidth: 1)
        }
    }

    private func loadingState(scale: CGFloat) -> some View {
        ProgressView()
            .tint(Color.compareAccent)
            .frame(maxWidth: .infinity)
    }

    private func card(scale: CGFloat, @ViewBuilder content: () -> some View) -> some View {
        content()
            .padding(16 * scale)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.compareCard)
            .clipShape(RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
                    .stroke(.white.opacity(0.07), lineWidth: 1)
            }
    }

    private func cardCaption(_ text: String, scale: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 11 * scale, weight: .semibold))
            .tracking(1 * scale)
            .foregroundStyle(Color.compareText)
    }

    private func columnHeaderRow(scale: CGFloat) -> some View {
        HStack(spacing: 6 * scale) {
            Spacer()

            Text(shortDateText(state.selectedDate))
                .frame(width: 64 * scale, alignment: .trailing)

            Color.clear
                .frame(width: 56 * scale, height: 1)

            Text("오늘")
                .frame(width: 64 * scale, alignment: .trailing)
        }
        .font(.system(size: 10 * scale, weight: .regular))
        .foregroundStyle(Color.compareMuted)
    }

    private func metricRow(
        title: String,
        left: String?,
        right: String?,
        delta: HistoryCompareDelta?,
        scale: CGFloat
    ) -> some View {
        HStack(spacing: 6 * scale) {
            Text(title)
                .font(.system(size: 12 * scale, weight: .regular))
                .foregroundStyle(Color.compareMuted)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(left ?? "-")
                .font(.system(size: 12 * scale, weight: .regular))
                .foregroundStyle(Color.compareText)
                .frame(width: 64 * scale, alignment: .trailing)

            deltaChipView(delta, scale: scale)
                .frame(width: 56 * scale)

            Text(right ?? "-")
                .font(.system(size: 12 * scale, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 64 * scale, alignment: .trailing)
        }
        .padding(.vertical, 8 * scale)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private func deltaChipView(_ delta: HistoryCompareDelta?, scale: CGFloat) -> some View {
        if let delta {
            Text(delta.text)
                .font(.system(size: 11 * scale, weight: .semibold))
                .foregroundStyle(delta.sentiment.textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 7 * scale)
                .padding(.vertical, 3 * scale)
                .background(delta.sentiment.backgroundColor)
                .clipShape(Capsule())
        } else {
            Color.clear
                .frame(height: 1)
        }
    }

    private var selectedMetrics: HistoryCompareDayMetrics {
        HistoryCompareDayMetrics(state: state)
    }

    private var todayMetrics: HistoryCompareDayMetrics {
        HistoryCompareDayMetrics(state: todayViewModel.state)
    }

    private func delta(
        selected: Int?,
        today: Int?,
        higherIsBetter: Bool,
        format: (Int) -> String
    ) -> HistoryCompareDelta? {
        guard let selected, let today else { return nil }
        let diff = today - selected
        guard diff != 0 else {
            return HistoryCompareDelta(text: "±0", sentiment: .neutral)
        }

        let text = (diff > 0 ? "+" : "-") + format(abs(diff))
        let isImproved = higherIsBetter ? diff > 0 : diff < 0
        return HistoryCompareDelta(text: text, sentiment: isImproved ? .positive : .negative)
    }

    private var compareInsight: (title: String, message: String) {
        if todayViewModel.state.errorMessage != nil {
            return (
                "💡 오늘 기록을 불러오지 못했어요",
                "네트워크 상태를 확인한 뒤 화면을 다시 열어주세요."
            )
        }

        guard let todayROI = todayMetrics.roi else {
            return (
                "💡 오늘은 아직 측정 전이에요",
                "PVT 측정을 완료하면 이 날과의 컨디션 비교 인사이트를 볼 수 있어요."
            )
        }

        guard let selectedROI = selectedMetrics.roi else {
            return (
                "💡 이 날의 측정 기록이 없어요",
                "측정 기록이 있는 날짜를 선택하면 오늘과 비교할 수 있어요."
            )
        }

        let roiDelta = todayROI - selectedROI
        return (compareInsightTitle(roiDelta: roiDelta), compareInsightMessage(roiDelta: roiDelta))
    }

    private func compareInsightTitle(roiDelta: Int) -> String {
        switch roiDelta {
        case 10...:
            return "💡 오늘 컨디션이 \(roiDelta)점 더 좋아요"
        case 3...9:
            return "💡 오늘이 \(roiDelta)점 더 높아요"
        case (-9)...(-3):
            return "💡 오늘이 \(-roiDelta)점 더 낮아요"
        case ...(-10):
            return "💡 오늘은 회복이 필요해 보여요"
        default:
            return "💡 두 날의 컨디션이 비슷해요"
        }
    }

    private func compareInsightMessage(roiDelta: Int) -> String {
        let sleepDelta = minutesDelta(\.totalMinutes)
        let deepDelta = minutesDelta(\.deepMinutes)
        let efficiencyDelta = optionalDelta(selectedMetrics.sleep?.efficiencyPercent, todayMetrics.sleep?.efficiencyPercent)
        let hrvDelta = optionalDelta(selectedMetrics.nightHrvMs, todayMetrics.nightHrvMs)
        let reactionDelta = optionalDelta(selectedMetrics.averageReactionMs, todayMetrics.averageReactionMs)
        let lapseDelta = optionalDelta(selectedMetrics.averageLapse, todayMetrics.averageLapse)

        if let sleepDelta, let reactionDelta, sleepDelta >= 30, reactionDelta <= -15 {
            return "수면이 \(durationText(sleepDelta)) 늘면서 평균 반응 속도도 \(-reactionDelta)ms 빨라졌어요. 좋은 흐름을 유지해보세요."
        }

        if let sleepDelta, let reactionDelta, sleepDelta <= -30, reactionDelta >= 15 {
            return "수면이 \(durationText(-sleepDelta)) 줄면서 반응 속도도 \(reactionDelta)ms 느려졌어요. 오늘은 조금 일찍 잠자리에 들어보세요."
        }

        if let deepDelta, deepDelta >= 20 {
            return "깊은 수면이 \(durationText(deepDelta)) 늘었어요. 신체 회복에 긍정적인 신호예요."
        }

        if let deepDelta, deepDelta <= -20 {
            return "깊은 수면이 \(durationText(-deepDelta)) 줄었어요. 오늘은 카페인과 늦은 운동을 줄여보세요."
        }

        if let reactionDelta, reactionDelta <= -15 {
            return "평균 반응 속도가 \(-reactionDelta)ms 빨라졌어요. 두뇌 각성도가 좋아진 상태예요."
        }

        if let reactionDelta, reactionDelta >= 15 {
            return "평균 반응 속도가 \(reactionDelta)ms 느려졌어요. 피로가 쌓였다면 짧은 휴식을 챙겨보세요."
        }

        if let lapseDelta, lapseDelta <= -2 {
            return "Lapse가 평균 \(-lapseDelta)회 줄었어요. 집중력이 안정적으로 유지되고 있어요."
        }

        if let lapseDelta, lapseDelta >= 2 {
            return "Lapse가 평균 \(lapseDelta)회 늘었어요. 집중이 흐트러지기 쉬운 상태일 수 있어요."
        }

        if let sleepDelta, sleepDelta >= 30 {
            return "수면 시간이 \(durationText(sleepDelta)) 늘었어요. 회복에 도움이 됐을 거예요."
        }

        if let sleepDelta, sleepDelta <= -30 {
            return "수면 시간이 \(durationText(-sleepDelta)) 줄었어요. 낮 동안 컨디션 변화를 살펴보세요."
        }

        if let efficiencyDelta, efficiencyDelta >= 5 {
            return "수면 효율이 \(efficiencyDelta)%p 올랐어요. 잠의 질이 좋아지고 있어요."
        }

        if let efficiencyDelta, efficiencyDelta <= -5 {
            return "수면 효율이 \(-efficiencyDelta)%p 내려갔어요. 취침 전 루틴을 점검해보세요."
        }

        if let hrvDelta, hrvDelta >= 5 {
            return "심박 변이도가 \(hrvDelta)ms 높아졌어요. 회복 상태가 좋아진 신호예요."
        }

        if let hrvDelta, hrvDelta <= -5 {
            return "심박 변이도가 \(hrvDelta * -1)ms 낮아졌어요. 몸의 회복이 더딜 수 있어요."
        }

        if roiDelta >= 3 {
            return "큰 지표 변화 없이 컨디션 점수가 올랐어요. 지금의 리듬을 유지해보세요."
        }

        if roiDelta <= -3 {
            return "지표 변화는 크지 않지만 점수가 낮아졌어요. 오늘은 무리하지 않는 게 좋겠어요."
        }

        return "수면과 반응 속도 모두 큰 차이 없이 안정적으로 유지되고 있어요."
    }

    private func minutesDelta(_ keyPath: KeyPath<HistoryDaySleepSummary, Int>) -> Int? {
        optionalDelta(
            selectedMetrics.sleep?[keyPath: keyPath],
            todayMetrics.sleep?[keyPath: keyPath]
        )
    }

    private func optionalDelta(_ selected: Int?, _ today: Int?) -> Int? {
        guard let selected, let today else { return nil }
        return today - selected
    }

    private func roiStatusTitle(_ score: Int) -> String {
        switch score {
        case 80...:
            return "최적의 방전 상태"
        case 65...79:
            return "안정적인 방전 상태"
        case 50...64:
            return "주의가 필요한 상태"
        default:
            return "회복이 필요한 상태"
        }
    }

    private func durationText(_ minutes: Int) -> String {
        guard minutes > 0 else { return "0m" }
        let hours = minutes / 60
        let remaining = minutes % 60
        if hours > 0 {
            return remaining > 0 ? "\(hours)h \(remaining)m" : "\(hours)h"
        }
        return "\(remaining)m"
    }

    private func headerDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "M월 d일 (E)"
        return formatter.string(from: date)
    }

    private func shortDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

private extension Color {
    static let compareBackground = Color(red: 0.039, green: 0.055, blue: 0.153)
    static let compareCard = Color(red: 0.078, green: 0.098, blue: 0.216)
    static let compareAccent = Color(red: 0.133, green: 0.827, blue: 0.933)
    static let compareText = Color(red: 0.7, green: 0.72, blue: 0.82)
    static let compareMuted = Color(red: 0.45, green: 0.47, blue: 0.6)
}

private struct HistoryCompareDayMetrics {
    let roi: Int?
    let pvtCount: Int
    let averageReactionMs: Int?
    let averageLapse: Int?
    let averageFalseStart: Int?
    let sleep: HistoryDaySleepSummary?

    var nightHrvMs: Int? {
        sleep?.nightHrvMs.map { Int($0.rounded()) }
    }

    init(state: HistoryDayDetailState) {
        roi = state.averageROI
        pvtCount = state.pvtCount
        averageReactionMs = Self.roundedAverage(state.evaluations.map(\.pvt.averageMilliseconds))
        averageLapse = Self.roundedAverage(state.evaluations.map(\.pvt.lapseCount))
        averageFalseStart = Self.roundedAverage(state.evaluations.map(\.pvt.falseStartCount))
        sleep = state.sleep
    }

    private static func roundedAverage(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        return Int((Double(values.reduce(0, +)) / Double(values.count)).rounded())
    }
}

private struct HistoryCompareDelta {
    let text: String
    let sentiment: Sentiment

    enum Sentiment {
        case positive
        case negative
        case neutral

        var textColor: Color {
            switch self {
            case .positive:
                return Color(red: 0.204, green: 0.827, blue: 0.6)
            case .negative:
                return Color(red: 0.969, green: 0.443, blue: 0.443)
            case .neutral:
                return Color.compareText
            }
        }

        var backgroundColor: Color {
            switch self {
            case .positive:
                return Color(red: 0.063, green: 0.725, blue: 0.506).opacity(0.16)
            case .negative:
                return Color(red: 0.937, green: 0.267, blue: 0.267).opacity(0.16)
            case .neutral:
                return Color.white.opacity(0.08)
            }
        }
    }
}
