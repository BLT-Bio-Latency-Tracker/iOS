import SwiftUI

struct HistoryDayDetailView: View {
    @StateObject private var viewModel: HistoryDayDetailViewModel
    @State private var pvtSortOption: HistoryDayPVTSortOption = .time
    @State private var selectedPVTMeasurement: PVTDetailMeasurement?
    let onBack: () -> Void
    let onDataChanged: (Date) async -> Void

    private let designWidth: CGFloat = 390

    init(
        date: Date,
        onBack: @escaping () -> Void,
        onDataChanged: @escaping (Date) async -> Void = { _ in }
    ) {
        self.onBack = onBack
        self.onDataChanged = onDataChanged
        _viewModel = StateObject(wrappedValue: HistoryDayDetailViewModel(date: date))
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / designWidth
            let contentWidth = max(0, proxy.size.width - 36 * scale)
            let horizontalInset = (proxy.size.width - contentWidth) / 2
            let topPadding = max(0, 38 * scale - proxy.safeAreaInsets.top)

            ZStack {
                Color.historyDayBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header(scale: scale)
                        .padding(.top, topPadding)
                        .padding(.horizontal, horizontalInset)
                        .padding(.bottom, 18 * scale)
                        .background(Color.historyDayBackground)
                        .zIndex(1)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            dayNavigation(scale: scale)
                                .padding(.top, 2 * scale)

                            if viewModel.state.isLoading {
                                loadingState(scale: scale)
                                    .padding(.top, 190 * scale)
                            } else if viewModel.state.hasData {
                                content(scale: scale)
                                    .padding(.top, 18 * scale)
                            } else {
                                emptyState(scale: scale)
                                    .padding(.top, 150 * scale)
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
            await viewModel.loadIfNeeded()
        }
        .navigationDestination(item: $selectedPVTMeasurement) { measurement in
            PVTMeasurementDetailView(measurement: measurement) {
                selectedPVTMeasurement = nil
            } onDeleted: {
                selectedPVTMeasurement = nil
                await viewModel.reloadAfterDeletion()
                await onDataChanged(viewModel.state.selectedDate)
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }
        .enablesInteractivePopGesture()
    }

    private func header(scale: CGFloat) -> some View {
        ZStack {
            Text(dateTitle(viewModel.state.selectedDate))
                .font(.system(size: 17 * scale, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)

            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 22 * scale, weight: .regular))
                        .foregroundStyle(.white.opacity(0.88))
                        .frame(width: 32 * scale, height: 32 * scale)
                        .background(Color.historyDayCard)
                        .clipShape(RoundedRectangle(cornerRadius: 10 * scale, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("뒤로가기")

                Spacer()
            }
        }
        .frame(height: 36 * scale)
    }

    private func dayNavigation(scale: CGFloat) -> some View {
        HStack {
            Button {
                viewModel.moveDay(by: -1)
            } label: {
                Text("‹ \(shortDateText(viewModel.state.selectedDate, offset: -1))")
                    .font(.system(size: 13 * scale, weight: .medium))
                    .foregroundStyle(Color.historyDayMuted)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                viewModel.moveToToday()
            } label: {
                Text("오늘로 이동")
                    .font(.system(size: 13 * scale, weight: .semibold))
                    .foregroundStyle(Color.historyDayAccent)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                viewModel.moveDay(by: 1)
            } label: {
                Text("\(shortDateText(viewModel.state.selectedDate, offset: 1)) ›")
                    .font(.system(size: 13 * scale, weight: .medium))
                    .foregroundStyle(Color.historyDayMuted.opacity(viewModel.canMoveToNextDay ? 1 : 0.35))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canMoveToNextDay)
        }
        .padding(.horizontal, 10 * scale)
        .frame(height: 24 * scale)
    }

    private func content(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            roiSummaryCard(scale: scale)

            roiTrendCard(scale: scale)
                .padding(.top, 18 * scale)

            sleepCard(scale: scale)
                .padding(.top, 18 * scale)

            pvtSection(scale: scale)
                .padding(.top, 28 * scale)

            actionButtons(scale: scale)
                .padding(.top, 20 * scale)

            Text("※ Brain ROI는 의료 진단이 아닌 컨디션 참고용 지표입니다")
                .font(.system(size: 11 * scale, weight: .regular))
                .foregroundStyle(Color.historyDayMuted.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 24 * scale)
        }
    }

    private func roiSummaryCard(scale: CGFloat) -> some View {
        let score = viewModel.state.averageROI ?? 0
        let status = HistoryDayROIStatus(score: score)

        return VStack(alignment: .leading, spacing: 0) {
            Text("BRAIN ROI INDEX")
                .font(.system(size: 11 * scale, weight: .semibold))
                .tracking(2.2 * scale)
                .foregroundStyle(.white.opacity(0.55))

            HStack(alignment: .center, spacing: 18 * scale) {
                Text(String(score))
                    .font(.system(size: 54 * scale, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(status.title)
                    .font(.system(size: 13 * scale, weight: .bold))
                    .foregroundStyle(status.color)
                    .padding(.horizontal, 24 * scale)
                    .frame(height: 28 * scale)
                    .background(status.color.opacity(0.16))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule()
                            .stroke(status.color.opacity(0.6), lineWidth: 1)
                    }
            }
            .padding(.top, 10 * scale)

            Text("PVT \(viewModel.state.pvtCount)회 측정 · 수면 \(sleepDurationText(viewModel.state.totalSleepMinutes))")
                .font(.system(size: 12 * scale, weight: .regular))
                .foregroundStyle(.white.opacity(0.62))
                .padding(.top, 2 * scale)
        }
        .padding(.horizontal, 16 * scale)
        .padding(.top, 16 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 140 * scale)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.264, green: 0.245, blue: 0.588),
                    Color(red: 0.031, green: 0.259, blue: 0.344)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22 * scale, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func roiTrendCard(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("\(shortDateText(viewModel.state.selectedDate)) ROI 변화")
                    .font(.system(size: 13 * scale, weight: .bold))
                    .foregroundStyle(Color.historyDayText)

                Spacer()

                Text("\(viewModel.state.pvtCount)회 측정")
                    .font(.system(size: 11 * scale, weight: .medium))
                    .foregroundStyle(Color.historyDayMuted)
            }

            HistoryROITrendChart(evaluations: viewModel.state.sortedEvaluations)
                .frame(height: 78 * scale)
                .padding(.top, 12 * scale)
        }
        .padding(.horizontal, 16 * scale)
        .padding(.vertical, 16 * scale)
        .frame(maxWidth: .infinity)
        .background(Color.historyDayCard)
        .clipShape(RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
    }

    private func sleepCard(scale: CGFloat) -> some View {
        let sleep = viewModel.state.sleep

        return VStack(alignment: .leading, spacing: 0) {
            Text("🌙 수면 데이터")
                .font(.system(size: 14 * scale, weight: .bold))
                .foregroundStyle(.white)

            Text(sleepDurationText(sleep?.totalMinutes))
                .font(.system(size: 28 * scale, weight: .heavy))
                .foregroundStyle(.white)
                .padding(.top, 12 * scale)

            if let bedStartAt = sleep?.bedStartAt,
               let bedEndAt = sleep?.bedEndAt {
                Text("입면 \(timeText(bedStartAt)) · 기상 \(timeText(bedEndAt))")
                    .font(.system(size: 12 * scale, weight: .regular))
                    .foregroundStyle(Color.historyDayText)
                    .padding(.top, 6 * scale)
            } else {
                Text("수면 단계 구간은 HealthKit 로컬 데이터 기준으로 표시됩니다")
                    .font(.system(size: 11 * scale, weight: .regular))
                    .foregroundStyle(Color.historyDayMuted)
                    .padding(.top, 6 * scale)
            }

            if let sleep, !sleep.stageSegments.isEmpty {
                sleepStageBar(sleep: sleep, scale: scale)
                    .padding(.top, 14 * scale)
            } else {
                Text("표시할 수면 구간 데이터가 없어요")
                    .font(.system(size: 12 * scale, weight: .medium))
                    .foregroundStyle(Color.historyDayMuted)
                    .padding(.top, 18 * scale)
            }
        }
        .padding(16 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.historyDayCard)
        .clipShape(RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
    }

    private func sleepStageBar(sleep: HistoryDaySleepSummary, scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8 * scale) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    ForEach(sleep.stageSegments) { segment in
                        segment.kind.color
                            .frame(
                                width: max(1, proxy.size.width * segment.durationRatio),
                                height: 12 * scale
                            )
                            .offset(x: proxy.size.width * segment.startRatio)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
                .background(.white.opacity(0.08))
                .clipShape(Capsule())
            }
            .frame(height: 12 * scale)

            HStack(spacing: 16 * scale) {
                stageRatioText(title: "얕은", minutes: sleep.coreMinutes, total: sleep.totalMinutes, color: .core, scale: scale)
                stageRatioText(title: "깊은", minutes: sleep.deepMinutes, total: sleep.totalMinutes, color: .deep, scale: scale)
                stageRatioText(title: "REM", minutes: sleep.remMinutes, total: sleep.totalMinutes, color: .rem, scale: scale)
                stageRatioText(title: "비수면", minutes: sleep.awakeMinutes, total: sleep.totalMinutes, color: .awake, scale: scale)
            }
        }
    }

    private func stageRatioText(
        title: String,
        minutes: Int,
        total: Int,
        color: HistoryDaySleepStageKind,
        scale: CGFloat
    ) -> some View {
        let ratio = total > 0 ? Int((Double(minutes) / Double(total) * 100).rounded()) : 0

        return Text("\(title) \(ratio)%")
            .font(.system(size: 11 * scale, weight: .medium))
            .foregroundStyle(color.color)
    }

    private func pvtSection(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12 * scale) {
            HStack {
                Text("\(shortDateText(viewModel.state.selectedDate)) PVT 측정 (\(viewModel.state.pvtCount)회)")
                    .font(.system(size: 13 * scale, weight: .bold))
                    .foregroundStyle(Color.historyDayText)

                Spacer()

                Menu {
                    ForEach(HistoryDayPVTSortOption.allCases) { option in
                        Button {
                            pvtSortOption = option
                        } label: {
                            if option == pvtSortOption {
                                Label(option.title, systemImage: "checkmark")
                            } else {
                                Text(option.title)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3 * scale) {
                        Text(pvtSortOption.title)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8 * scale, weight: .bold))
                    }
                    .font(.system(size: 11 * scale, weight: .medium))
                    .foregroundStyle(Color.historyDayAccent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8 * scale)

            ForEach(sortedPVTList) { evaluation in
                Button {
                    selectedPVTMeasurement = pvtMeasurement(from: evaluation)
                } label: {
                    pvtRow(evaluation, scale: scale)
                }
                .buttonStyle(.plain)
                .id(evaluation.id)
            }
        }
    }

    private var sortedPVTList: [HistoryDayEvaluation] {
        switch pvtSortOption {
        case .time:
            return viewModel.state.sortedEvaluations
        case .roiHigh:
            return viewModel.state.evaluations.sorted {
                if $0.finalScore == $1.finalScore {
                    return $0.measuredAt < $1.measuredAt
                }
                return $0.finalScore > $1.finalScore
            }
        case .roiLow:
            return viewModel.state.evaluations.sorted {
                if $0.finalScore == $1.finalScore {
                    return $0.measuredAt < $1.measuredAt
                }
                return $0.finalScore < $1.finalScore
            }
        }
    }

    private func pvtRow(_ evaluation: HistoryDayEvaluation, scale: CGFloat) -> some View {
        let status = HistoryDayROIStatus(score: evaluation.finalScore)

        return HStack(alignment: .center, spacing: 12 * scale) {
            VStack(alignment: .leading, spacing: 8 * scale) {
                Text("\(timeText(evaluation.measuredAt)) · \(dayPartText(evaluation.measuredAt))")
                    .font(.system(size: 11 * scale, weight: .bold))
                    .foregroundStyle(Color.historyDayBackground)
                    .padding(.horizontal, 7 * scale)
                    .frame(height: 22 * scale)
                    .background(dayPartColor(evaluation.measuredAt))
                    .clipShape(Capsule())

                Text("평균 \(evaluation.pvt.averageMilliseconds)ms · BEST \(evaluation.pvt.bestMilliseconds ?? 0)ms · Lapse \(evaluation.pvt.lapseCount)")
                    .font(.system(size: 11 * scale, weight: .regular))
                    .foregroundStyle(Color.historyDayText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text("Trial \(evaluation.pvt.totalCount)/7 완료 · False Start \(evaluation.pvt.falseStartCount)")
                    .font(.system(size: 10 * scale, weight: .regular))
                    .foregroundStyle(Color.historyDayMuted)
            }

            Spacer()

            VStack(spacing: 4 * scale) {
                Text("ROI")
                    .font(.system(size: 10 * scale, weight: .medium))
                    .foregroundStyle(Color.historyDayMuted)

                Text(String(evaluation.finalScore))
                    .font(.system(size: 18 * scale, weight: .heavy))
                    .foregroundStyle(.white)
            }

            Text(status.shortTitle)
                .font(.system(size: 11 * scale, weight: .bold))
                .foregroundStyle(Color.historyDayBackground)
                .frame(width: 44 * scale, height: 24 * scale)
                .background(status.color)
                .clipShape(Capsule())

            Image(systemName: "chevron.right")
                .font(.system(size: 12 * scale, weight: .semibold))
                .foregroundStyle(Color.historyDayMuted)
                .frame(width: 10 * scale)
        }
        .padding(.horizontal, 16 * scale)
        .frame(maxWidth: .infinity)
        .frame(height: 86 * scale)
        .background(Color.historyDayCard)
        .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
    }

    private func pvtMeasurement(from evaluation: HistoryDayEvaluation) -> PVTDetailMeasurement {
        PVTDetailMeasurement(
            id: evaluation.id,
            measurementId: evaluation.pvt.measurementId,
            measuredAt: evaluation.measuredAt,
            averageMilliseconds: evaluation.pvt.averageMilliseconds,
            bestMilliseconds: evaluation.pvt.bestMilliseconds,
            lapseCount: evaluation.pvt.lapseCount,
            falseStartCount: evaluation.pvt.falseStartCount,
            totalCount: evaluation.pvt.totalCount,
            rawReactionTimes: evaluation.pvt.rawReactionTimes
        )
    }

    private func actionButtons(scale: CGFloat) -> some View {
        HStack(spacing: 8 * scale) {
            Button {} label: {
                Text("공유 / 내보내기")
                    .font(.system(size: 13 * scale, weight: .semibold))
                    .foregroundStyle(Color.historyDayText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48 * scale)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14 * scale, style: .continuous)
                            .stroke(Color.historyDayMuted.opacity(0.45), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

            Button {} label: {
                Text("오늘과 비교")
                    .font(.system(size: 13 * scale, weight: .bold))
                    .foregroundStyle(Color.historyDayBackground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48 * scale)
                    .background(Color.historyDayAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4 * scale)
    }

    private func loadingState(scale: CGFloat) -> some View {
        ProgressView()
            .tint(Color.historyDayAccent)
            .frame(maxWidth: .infinity)
    }

    private func emptyState(scale: CGFloat) -> some View {
        VStack(spacing: 12 * scale) {
            Text("해당 날짜의 기록이 없어요")
                .font(.system(size: 16 * scale, weight: .bold))
                .foregroundStyle(.white)

            Text("측정 기록이 있는 날짜를 선택하면 상세 결과를 볼 수 있어요")
                .font(.system(size: 12 * scale, weight: .regular))
                .foregroundStyle(Color.historyDayMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func dateTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy년 M월 d일 (E)"
        return formatter.string(from: date)
    }

    private func shortDateText(_ date: Date, offset: Int = 0) -> String {
        let target = Calendar.korea.date(byAdding: .day, value: offset, to: date) ?? date
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "M/d"
        return formatter.string(from: target)
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func dayPartText(_ date: Date) -> String {
        let hour = Calendar.korea.component(.hour, from: date)
        switch hour {
        case 5..<12:
            return "아침"
        case 12..<18:
            return "오후"
        default:
            return "야간"
        }
    }

    private func dayPartColor(_ date: Date) -> Color {
        let hour = Calendar.korea.component(.hour, from: date)
        switch hour {
        case 5..<12:
            return Color.historyDayAccent
        case 12..<18:
            return Color(red: 0.961, green: 0.62, blue: 0.043)
        default:
            return Color.historyDayPrimary
        }
    }

    private func sleepDurationText(_ minutes: Int?) -> String {
        guard let minutes, minutes > 0 else { return "데이터 없음" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

private struct HistoryROITrendChart: View {
    let evaluations: [HistoryDayEvaluation]

    var body: some View {
        GeometryReader { proxy in
            let points = chartPoints(size: proxy.size)

            ZStack {
                if points.count > 1 {
                    Path { path in
                        path.move(to: points[0].point)
                        for item in points.dropFirst() {
                            path.addLine(to: item.point)
                        }
                    }
                    .stroke(Color.historyDayAccent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }

                ForEach(points, id: \.evaluation.id) { item in
                    VStack(spacing: 3) {
                        Text(String(item.evaluation.finalScore))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)

                        Circle()
                            .fill(Color.historyDayAccent)
                            .frame(width: 10, height: 10)

                        Text(timeText(item.evaluation.measuredAt))
                            .font(.system(size: 9, weight: .regular))
                            .foregroundStyle(Color.historyDayMuted)
                    }
                    .position(x: item.point.x, y: item.point.y + 4)
                }
            }
        }
    }

    private func chartPoints(size: CGSize) -> [(evaluation: HistoryDayEvaluation, point: CGPoint)] {
        let sorted = evaluations.sorted { $0.measuredAt < $1.measuredAt }
        guard !sorted.isEmpty else { return [] }

        let horizontalPadding: CGFloat = sorted.count == 1 ? size.width / 2 : 28
        let usableWidth = max(1, size.width - horizontalPadding * 2)
        let usableHeight = max(1, size.height - 34)
        let minScore = max(0, (sorted.map(\.finalScore).min() ?? 0) - 6)
        let maxScore = min(100, (sorted.map(\.finalScore).max() ?? 100) + 6)
        let range = max(1, maxScore - minScore)

        return sorted.enumerated().map { index, evaluation in
            let x: CGFloat
            if sorted.count == 1 {
                x = horizontalPadding
            } else {
                x = horizontalPadding + usableWidth * CGFloat(index) / CGFloat(sorted.count - 1)
            }
            let normalized = CGFloat(evaluation.finalScore - minScore) / CGFloat(range)
            let y = 18 + usableHeight * (1 - normalized)
            return (evaluation, CGPoint(x: x, y: y))
        }
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

private enum HistoryDayPVTSortOption: String, CaseIterable, Identifiable {
    case time
    case roiHigh
    case roiLow

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .time:
            return "시간순"
        case .roiHigh:
            return "ROI 높은순"
        case .roiLow:
            return "ROI 낮은순"
        }
    }
}

private enum HistoryDayROIStatus {
    case excellent
    case stable
    case caution
    case low

    init(score: Int) {
        switch score {
        case 80...:
            self = .excellent
        case 65...79:
            self = .stable
        case 50...64:
            self = .caution
        default:
            self = .low
        }
    }

    var title: String {
        switch self {
        case .excellent:
            return "최적 컨디션"
        case .stable:
            return "안정적 컨디션"
        case .caution:
            return "주의 컨디션"
        case .low:
            return "회복 필요"
        }
    }

    var shortTitle: String {
        switch self {
        case .excellent, .stable:
            return "안정"
        case .caution:
            return "주의"
        case .low:
            return "하락"
        }
    }

    var color: Color {
        switch self {
        case .excellent, .stable:
            return Color(red: 0.063, green: 0.725, blue: 0.506)
        case .caution:
            return Color(red: 0.133, green: 0.827, blue: 0.933)
        case .low:
            return Color(red: 0.961, green: 0.62, blue: 0.043)
        }
    }
}

private extension Calendar {
    static var korea: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }
}

private extension Color {
    static let historyDayBackground = Color(red: 0.039, green: 0.055, blue: 0.153)
    static let historyDayCard = Color(red: 0.078, green: 0.098, blue: 0.216)
    static let historyDayPrimary = Color(red: 0.486, green: 0.361, blue: 1)
    static let historyDayAccent = Color(red: 0.133, green: 0.827, blue: 0.933)
    static let historyDayText = Color(red: 0.7, green: 0.72, blue: 0.82)
    static let historyDayMuted = Color(red: 0.45, green: 0.47, blue: 0.6)
}
