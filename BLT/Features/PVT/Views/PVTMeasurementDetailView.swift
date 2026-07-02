import SwiftUI

struct PVTMeasurementDetailView: View {
    let measurement: PVTDetailMeasurement
    let onBack: () -> Void

    private let designWidth: CGFloat = 390

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / designWidth
            let contentWidth = max(0, proxy.size.width - 40 * scale)
            let horizontalInset = (proxy.size.width - contentWidth) / 2
            let topPadding = max(0, 40 * scale - proxy.safeAreaInsets.top)

            ZStack {
                Color.pvtRecordBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header(scale: scale)
                        .padding(.top, topPadding)
                        .padding(.horizontal, horizontalInset)
                        .padding(.bottom, 22 * scale)
                        .background(Color.pvtRecordBackground)
                        .zIndex(1)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            summarySection(scale: scale)

                            statCards(scale: scale)
                                .padding(.top, 22 * scale)

                            Text("Trial 분포")
                                .font(.system(size: 13 * scale, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.88))
                                .padding(.top, 30 * scale)
                                .padding(.leading, 8 * scale)

                            PVTTrialDistributionCard(measurement: measurement, scale: scale)
                                .padding(.top, 16 * scale)

                            metricRows(scale: scale)
                                .padding(.top, 28 * scale)
                        }
                        .padding(.horizontal, horizontalInset)
                        .padding(.bottom, 34 * scale)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .enablesInteractivePopGesture()
    }

    private func header(scale: CGFloat) -> some View {
        ZStack {
            Text("PVT 기록 상세")
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
                .accessibilityLabel("뒤로가기")

                Spacer()
            }
        }
        .frame(height: 27 * scale)
    }

    private func summarySection(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(datePrefixText(measurement.measuredAt)) \(timeText(measurement.measuredAt)) · PVT 결과")
                .font(.system(size: 12 * scale, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))

            HStack(alignment: .lastTextBaseline, spacing: 0) {
                Text(String(measurement.averageMilliseconds))
                    .font(.system(size: 44 * scale, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("ms 평균")
                    .font(.system(size: 13 * scale, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.leading, 1 * scale)
                    .padding(.bottom, 8 * scale)
            }
            .padding(.top, 11 * scale)
        }
        .padding(.leading, 8 * scale)
    }

    private func statCards(scale: CGFloat) -> some View {
        HStack(spacing: 16 * scale) {
            statCard(
                title: "BEST",
                value: measurement.bestMilliseconds.map(String.init) ?? "-",
                suffix: measurement.bestMilliseconds == nil ? "" : "ms",
                valueColor: Color.pvtRecordPositive,
                scale: scale
            )

            statCard(
                title: "LAPSE",
                value: String(measurement.lapseCount),
                suffix: "회 (>500ms)",
                valueColor: .white,
                scale: scale
            )
        }
    }

    private func statCard(
        title: String,
        value: String,
        suffix: String,
        valueColor: Color,
        scale: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 10 * scale, weight: .semibold))
                .tracking(1.5 * scale)
                .foregroundStyle(.white.opacity(0.55))

            HStack(alignment: .lastTextBaseline, spacing: 8 * scale) {
                Text(value)
                    .font(.system(size: 22 * scale, weight: .heavy))
                    .foregroundStyle(valueColor)

                Text(suffix)
                    .font(.system(size: 12 * scale, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.bottom, 3 * scale)
            }
            .padding(.top, 8 * scale)
        }
        .padding(.horizontal, 16 * scale)
        .padding(.top, 5 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 80 * scale)
        .background(Color.pvtRecordCard)
        .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func metricRows(scale: CGFloat) -> some View {
        VStack(spacing: 10 * scale) {
            metricRow(
                title: "False Start",
                value: "\(measurement.falseStartCount)회",
                valueColor: .white,
                scale: scale
            )
            metricRow(
                title: "응답 안정성",
                value: responseStabilityStatus.title,
                valueColor: responseStabilityStatus.color,
                scale: scale
            )
            metricRow(
                title: "각성 수준",
                value: arousalLevelStatus.title,
                valueColor: arousalLevelStatus.color,
                scale: scale
            )
        }
    }

    private func metricRow(
        title: String,
        value: String,
        valueColor: Color,
        scale: CGFloat
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14 * scale, weight: .regular))
                .foregroundStyle(.white.opacity(0.65))
            Spacer()
            Text(value)
                .font(.system(size: 14 * scale, weight: .bold))
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, 16 * scale)
        .frame(height: 44 * scale)
        .background(Color.pvtRecordCard)
        .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var responseStabilityStatus: PVTRecordMetricStatus {
        if measurement.lapseCount <= 1 && measurement.falseStartCount <= 1 {
            return .good
        }
        if measurement.lapseCount <= 2 && measurement.falseStartCount <= 3 {
            return .caution
        }
        return .unstable
    }

    private var arousalLevelStatus: PVTRecordMetricStatus {
        switch measurement.averageMilliseconds {
        case ...320:
            return .good
        case ...350:
            return .caution
        default:
            return .low
        }
    }

    private func datePrefixText(_ date: Date) -> String {
        if Self.koreaCalendar.isDateInToday(date) {
            return "오늘"
        }
        return Self.dateFormatter.string(from: date)
    }

    private func timeText(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        formatter.dateFormat = "M월 d일"
        return formatter
    }()

    private static let koreaCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }()
}

private enum PVTRecordMetricStatus {
    case good
    case caution
    case unstable
    case low

    var title: String {
        switch self {
        case .good:
            return "양호"
        case .caution:
            return "주의"
        case .unstable:
            return "불안정"
        case .low:
            return "저하"
        }
    }

    var color: Color {
        switch self {
        case .good:
            return .pvtRecordPositive
        case .caution, .unstable, .low:
            return .pvtRecordCaution
        }
    }
}

private struct PVTTrialDistributionCard: View {
    let measurement: PVTDetailMeasurement
    let scale: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            PVTTrialDistributionChart(reactionTimes: measurement.rawReactionTimes)
                .frame(height: 138 * scale)

            Text("350ms 기준선")
                .font(.system(size: 11 * scale, weight: .regular))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.leading, 16 * scale)
                .padding(.bottom, 16 * scale)
        }
        .padding(.horizontal, 16 * scale)
        .frame(height: 140 * scale)
        .background(Color.pvtRecordCard)
        .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct PVTTrialDistributionChart: View {
    let reactionTimes: [Int]

    private let baseline: Int = 350

    var body: some View {
        GeometryReader { proxy in
            let points = chartPoints(in: proxy.size)
            let baselineY = yPosition(for: baseline, in: proxy.size)

            ZStack {
                Color.clear

                Path { path in
                    path.move(to: CGPoint(x: 0, y: baselineY))
                    path.addLine(to: CGPoint(x: proxy.size.width, y: baselineY))
                }
                .stroke(.white.opacity(0.14), lineWidth: 1)

                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    Circle()
                        .fill(dotColor(for: reactionTimes[index]))
                        .frame(width: 10, height: 10)
                        .position(point)
                }
            }
        }
    }

    private func chartPoints(in size: CGSize) -> [CGPoint] {
        guard !reactionTimes.isEmpty else { return [] }

        let horizontalPadding: CGFloat = 22
        let verticalPadding: CGFloat = 28
        let chartWidth = max(1, size.width - horizontalPadding * 2)
        let denominator = max(1, reactionTimes.count - 1)

        return reactionTimes.enumerated().map { index, value in
            let x = horizontalPadding + chartWidth * CGFloat(index) / CGFloat(denominator)
            let y = yPosition(for: value, in: size, verticalPadding: verticalPadding)
            return CGPoint(x: x, y: y)
        }
    }

    private func yPosition(
        for value: Int,
        in size: CGSize,
        verticalPadding: CGFloat = 28
    ) -> CGFloat {
        let chartHeight = max(1, size.height - verticalPadding * 2)
        let clamped = min(max(value, 0), 500)
        let ratio = CGFloat(clamped) / 500
        return verticalPadding + chartHeight * (1 - ratio)
    }

    private func dotColor(for value: Int) -> Color {
        value <= baseline ? .pvtRecordPositive : .pvtRecordCaution
    }
}

private extension Color {
    static let pvtRecordBackground = Color(red: 0.039, green: 0.055, blue: 0.153)
    static let pvtRecordCard = Color(red: 0.078, green: 0.098, blue: 0.216)
    static let pvtRecordPositive = Color(red: 0.063, green: 0.725, blue: 0.506)
    static let pvtRecordCaution = Color(red: 0.961, green: 0.62, blue: 0.043)
}
