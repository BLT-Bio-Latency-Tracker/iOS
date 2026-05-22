import SwiftUI

struct SleepDetailView: View {
    let sleep: TodaySleepData
    let onBack: () -> Void

    private let designWidth: CGFloat = 390

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / designWidth
            let contentWidth = max(0, proxy.size.width - 40 * scale)
            let horizontalInset = (proxy.size.width - contentWidth) / 2
            let topPadding = max(8 * scale, 56 * scale - proxy.safeAreaInsets.top)

            ZStack {
                Color.sleepDetailBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        header(scale: scale)
                            .padding(.top, topPadding)

                        summarySection(scale: scale)
                            .padding(.top, 25 * scale)

                        stageDistributionSection(scale: scale)
                            .padding(.top, 27 * scale)

                        detailMetricsSection(scale: scale)
                            .padding(.top, 31 * scale)

                        Spacer(minLength: 0)

                        insightCard(scale: scale)
                            .padding(.top, 90 * scale)
                            .padding(.bottom, 34 * scale)
                    }
                    .padding(.horizontal, horizontalInset)
                    .frame(minHeight: proxy.size.height)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func header(scale: CGFloat) -> some View {
        ZStack {
            Text("수면 상세")
                .font(.system(size: 16 * scale, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)

            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 22 * scale, weight: .regular))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 30 * scale, height: 27 * scale)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .frame(height: 27 * scale)
    }

    private func summarySection(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("어젯밤 수면")
                .font(.system(size: 12 * scale, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))

            HStack(alignment: .bottom, spacing: 16 * scale) {
                Text(sleep.totalSleepText)
                    .font(.system(size: 44 * scale, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                if let differenceText = sleep.differenceText {
                    Text(differenceText)
                        .font(.system(size: 12 * scale, weight: .bold))
                        .foregroundStyle(differenceColor)
                        .frame(width: 70 * scale, height: 28 * scale)
                        .background(differenceColor.opacity(0.18))
                        .clipShape(Capsule())
                        .overlay {
                            Capsule()
                                .stroke(differenceColor.opacity(0.4), lineWidth: 1)
                        }
                        .padding(.bottom, 8 * scale)
                }
            }
            .padding(.top, 3 * scale)

            Text("기상 \(sleep.bedEndText)  ·  입면 \(sleep.bedStartText)")
                .font(.system(size: 13 * scale, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.top, 1 * scale)
        }
    }

    private func stageDistributionSection(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("수면 단계 분포")
                .font(.system(size: 12 * scale, weight: .semibold))
                .tracking(0.5 * scale)
                .foregroundStyle(.white.opacity(0.85))

            SleepDetailTimelineBar(stages: sleep.stages)
                .frame(height: 14 * scale)
                .padding(.top, 11 * scale)

            HStack(spacing: 0) {
                stageLabel("얕은 수면", minutes: sleep.coreMinutes, color: Color.sleepDetailCyan, denominator: stageDenominator)
                    .frame(maxWidth: .infinity, alignment: .leading)

                stageLabel("깊은 수면", minutes: sleep.deepMinutes, color: Color.sleepDetailPrimary, denominator: stageDenominator)
                    .frame(maxWidth: .infinity, alignment: .center)

                stageLabel("REM", minutes: sleep.remMinutes, color: Color.sleepDetailRem, denominator: stageDenominator)
                    .frame(maxWidth: .infinity, alignment: .center)

                stageLabel("비수면", minutes: sleep.awakeMinutes, color: Color.sleepDetailNegative, denominator: stageDenominator)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: 10.5 * scale, weight: .medium))
            .padding(.top, 12 * scale)
        }
    }

    private func detailMetricsSection(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("세부 지표")
                .font(.system(size: 12 * scale, weight: .semibold))
                .tracking(0.5 * scale)
                .foregroundStyle(.white.opacity(0.85))

            VStack(spacing: 8 * scale) {
                metricRow(title: "수면 효율", value: "\(sleepEfficiencyPercent)%", scale: scale)
                metricRow(title: "REM 비율", value: "\(stagePercent(sleep.remMinutes, denominator: max(sleep.totalMinutes, 1)))%", scale: scale)
                metricRow(title: "깊은 수면 비율", value: "\(stagePercent(sleep.deepMinutes, denominator: max(sleep.totalMinutes, 1)))%", scale: scale)
                metricRow(title: "깬 횟수", value: "\(sleep.awakeCount)회", scale: scale)
                metricRow(title: "총 침대 시간", value: durationText(from: sleep.inBedMinutes), scale: scale)
            }
            .padding(.top, 17 * scale)
        }
    }

    private func metricRow(title: String, value: String, scale: CGFloat) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13 * scale, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            Spacer()

            Text(value)
                .font(.system(size: 14 * scale, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 16 * scale)
        .frame(maxWidth: .infinity)
        .frame(height: 44 * scale)
        .background(Color.sleepDetailCard)
        .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func insightCard(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 13 * scale) {
            Text(insightTitle)
                .font(.system(size: 13 * scale, weight: .semibold))
                .foregroundStyle(Color.sleepDetailCyan)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(insightMessage)
                .font(.system(size: 11 * scale, weight: .regular))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 16 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 70 * scale)
        .background(Color.sleepDetailCyan.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14 * scale, style: .continuous)
                .stroke(Color.sleepDetailCyan.opacity(0.3), lineWidth: 1)
        }
    }

    private func stageLabel(
        _ title: String,
        minutes: Int,
        color: Color,
        denominator: Int
    ) -> some View {
        Text("\(title) \(stagePercent(minutes, denominator: denominator))%")
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var differenceColor: Color {
        switch sleep.differenceDirection {
        case .positive:
            return Color.sleepDetailPositive
        case .negative:
            return Color.sleepDetailNegative
        case .neutral, .none:
            return Color.sleepDetailMuted
        }
    }

    private var stageDenominator: Int {
        max(sleep.coreMinutes + sleep.deepMinutes + sleep.remMinutes + sleep.awakeMinutes, 1)
    }

    private var sleepEfficiencyPercent: Int {
        guard sleep.inBedMinutes > 0 else { return 0 }
        return Int((Double(sleep.totalMinutes) / Double(sleep.inBedMinutes) * 100).rounded())
    }

    private var insightTitle: String {
        if sleep.bedStartText > "23:00" {
            return "💡 23시 이전 입면을 시도해보세요"
        }

        if sleep.awakeCount >= 3 {
            return "💡 중간 각성을 줄이는 루틴이 필요해요"
        }

        return "💡 지금의 수면 리듬을 유지해보세요"
    }

    private var insightMessage: String {
        if sleep.bedStartText > "23:00" {
            return "오늘 REM이 늦게 시작됐어요. 일찍 자면 회복이 좋아집니다."
        }

        if sleep.awakeCount >= 3 {
            return "수면 중 깬 시간이 많았어요. 취침 전 자극을 줄여보세요."
        }

        return "수면 단계 균형이 안정적이에요. 같은 시간대에 잠들어보세요."
    }

    private func stagePercent(_ minutes: Int, denominator: Int) -> Int {
        guard denominator > 0 else { return 0 }
        return Int((Double(minutes) / Double(denominator) * 100).rounded())
    }

    private func durationText(from minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }
}

private struct SleepDetailTimelineBar: View {
    let stages: [TodaySleepStage]

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
            return Color.sleepDetailCyan.opacity(0.72)
        case .deep:
            return Color.sleepDetailPrimary
        case .rem:
            return Color.sleepDetailRem
        case .awake:
            return Color.sleepDetailNegative
        }
    }
}

private extension Color {
    static let sleepDetailBackground = Color(red: 0.039, green: 0.055, blue: 0.153)
    static let sleepDetailCard = Color(red: 0.078, green: 0.098, blue: 0.216)
    static let sleepDetailPrimary = Color(red: 0.486, green: 0.361, blue: 1)
    static let sleepDetailCyan = Color(red: 0.133, green: 0.827, blue: 0.933)
    static let sleepDetailPositive = Color(red: 0.063, green: 0.725, blue: 0.506)
    static let sleepDetailNegative = Color(red: 0.937, green: 0.267, blue: 0.267)
    static let sleepDetailMuted = Color(red: 0.62, green: 0.66, blue: 0.82)
    static let sleepDetailRem = Color(red: 0.961, green: 0.62, blue: 0.043)
}
