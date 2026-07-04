import SwiftUI
import UIKit

struct HistoryReportPreviewView: View {
    let state: HistoryDayDetailState
    let onClose: () -> Void

    @State private var sharePDFItem: ReportPDFItem?

    private let designWidth: CGFloat = 390
    private let profileSnapshot = LocalProfileStore().snapshot(
        fallback: LocalProfileSnapshot(
            name: "Bryki",
            birthYear: nil,
            gender: nil,
            jobGroup: nil
        )
    )

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / designWidth
            let contentWidth = max(0, proxy.size.width - 32 * scale)
            let horizontalInset = (proxy.size.width - contentWidth) / 2
            let topPadding = max(12 * scale, 28 * scale - proxy.safeAreaInsets.top)

            ZStack {
                ReportColor.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header(scale: scale)
                        .padding(.top, topPadding)
                        .padding(.horizontal, horizontalInset)
                        .padding(.bottom, 8 * scale)
                        .background(ReportColor.card)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            reportHero(scale: scale)
                                .padding(.top, 16 * scale)

                            sectionTitle("01. 종합 점수", scale: scale)
                                .padding(.top, 24 * scale)

                            totalScoreCard(scale: scale)
                                .padding(.top, 12 * scale)

                            sectionTitle("02. 수면 데이터", scale: scale)
                                .padding(.top, 26 * scale)

                            sleepCard(scale: scale)
                                .padding(.top, 12 * scale)

                            sectionTitle("03. PVT 검사 · \(state.pvtCount)회 측정", scale: scale)
                                .padding(.top, 26 * scale)

                            pvtCard(scale: scale)
                                .padding(.top, 12 * scale)
                        }
                        .padding(.horizontal, horizontalInset)
                        .padding(.bottom, 18 * scale)
                    }

                    footer(scale: scale)
                        .padding(.horizontal, horizontalInset)
                        .padding(.vertical, 18 * scale)
                        .background(ReportColor.footer)
                }
            }
        }
        .preferredColorScheme(.dark)
        .enablesInteractivePopGesture()
        .sheet(item: $sharePDFItem) { item in
            ReportActivityShareSheet(items: [item.url])
        }
    }

    private func header(scale: CGFloat) -> some View {
        ZStack {
            VStack(spacing: 2 * scale) {
                Text("보고서 미리보기")
                    .font(.system(size: 18 * scale, weight: .bold))
                    .foregroundStyle(.white)

                Text("PDF · 1 페이지")
                    .font(.system(size: 11 * scale, weight: .regular))
                    .foregroundStyle(ReportColor.text)
            }
            .frame(maxWidth: .infinity)

            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18 * scale, weight: .regular))
                        .foregroundStyle(.white)
                        .frame(width: 42 * scale, height: 42 * scale)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("닫기")

                Spacer()

                Button {
                    sharePDFItem = makeReportPDF().map(ReportPDFItem.init)
                } label: {
                    Text("공유")
                        .font(.system(size: 14 * scale, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 42 * scale, height: 42 * scale)
                        .background(ReportColor.gradient)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("공유")
            }
        }
        .frame(height: 48 * scale)
    }

    private var reportDocument: some View {
        VStack(alignment: .leading, spacing: 0) {
            reportHero(scale: 1)
                .padding(.top, 20)

            sectionTitle("01. 종합 점수", scale: 1)
                .padding(.top, 24)

            totalScoreCard(scale: 1)
                .padding(.top, 12)

            sectionTitle("02. 수면 데이터", scale: 1)
                .padding(.top, 26)

            sleepCard(scale: 1)
                .padding(.top, 12)

            sectionTitle("03. PVT 검사 · \(state.pvtCount)회 측정", scale: 1)
                .padding(.top, 26)

            pvtCard(scale: 1)
                .padding(.top, 12)

            footer(scale: 1)
                .padding(.top, 28)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .frame(width: designWidth)
        .background(ReportColor.background)
        .environment(\.colorScheme, .dark)
    }

    @MainActor
    private func makeReportPDF() -> URL? {
        let renderer = ImageRenderer(content: reportDocument)
        renderer.proposedSize = ProposedViewSize(width: designWidth, height: nil)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileNameText)
        try? FileManager.default.removeItem(at: url)

        var isRendered = false
        renderer.render { size, renderContext in
            var mediaBox = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(url: url as CFURL),
                  let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
                return
            }

            pdfContext.beginPDFPage(nil)
            renderContext(pdfContext)
            pdfContext.endPDFPage()
            pdfContext.closePDF()
            isRendered = true
        }

        return isRendered ? url : nil
    }

    private func reportHero(scale: CGFloat) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 7 * scale) {
                HStack(spacing: 10 * scale) {
                    Text("⚡")
                        .font(.system(size: 17 * scale, weight: .bold))
                    Text("Bryki")
                        .font(.system(size: 18 * scale, weight: .heavy))
                }
                .foregroundStyle(.white)

                Text("Brain ROI · 일별 보고서")
                    .font(.system(size: 12 * scale, weight: .regular))
                    .foregroundStyle(.white.opacity(0.85))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 9 * scale) {
                Text(reportDateText(state.selectedDate))
                    .font(.system(size: 17 * scale, weight: .bold))
                    .foregroundStyle(.white)

                Text("\(profileSnapshot.name) · v\(appVersionText)")
                    .font(.system(size: 11 * scale, weight: .regular))
                    .foregroundStyle(.white.opacity(0.82))
            }
        }
        .padding(.horizontal, 16 * scale)
        .frame(maxWidth: .infinity)
        .frame(height: 80 * scale)
        .background(ReportColor.gradient)
        .clipShape(RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
    }

    private func sectionTitle(_ text: String, scale: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 13 * scale, weight: .bold))
            .foregroundStyle(ReportColor.text)
            .padding(.leading, 8 * scale)
    }

    private func totalScoreCard(scale: CGFloat) -> some View {
        let score = state.averageROI ?? 0
        let status = ReportROIStatus(score: score)

        return HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 0) {
                Text("BRAIN ROI INDEX")
                    .font(.system(size: 11 * scale, weight: .semibold))
                    .tracking(2 * scale)
                    .foregroundStyle(ReportColor.text)

                Text(String(score))
                    .font(.system(size: 56 * scale, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.top, 8 * scale)

                Text(status.reportTitle)
                    .font(.system(size: 14 * scale, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.top, 2 * scale)
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 10 * scale)
                Circle()
                    .trim(from: 0, to: CGFloat(max(0, min(score, 100))) / 100)
                    .stroke(status.color, style: StrokeStyle(lineWidth: 10 * scale, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
                Text(String(score))
                    .font(.system(size: 24 * scale, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .frame(width: 78 * scale, height: 78 * scale)
            .padding(.top, 26 * scale)
        }
        .padding(16 * scale)
        .frame(maxWidth: .infinity)
        .frame(height: 144 * scale)
        .background(ReportColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        }
    }

    private func sleepCard(scale: CGFloat) -> some View {
        let sleep = state.sleep
        let hasSleep = sleep != nil

        return VStack(alignment: .leading, spacing: 0) {
            Text("🌙  수면 \(durationText(sleep?.totalMinutes))")
                .font(.system(size: 15 * scale, weight: .bold))
                .foregroundStyle(.white)

            if let sleep,
               let bedStartAt = sleep.bedStartAt,
               let bedEndAt = sleep.bedEndAt {
                Text(sleepTimeSummaryText(sleep: sleep, bedStartAt: bedStartAt, bedEndAt: bedEndAt))
                    .font(.system(size: 11 * scale, weight: .regular))
                    .foregroundStyle(ReportColor.text)
                    .padding(.top, 12 * scale)
            } else if sleep != nil {
                Text("서버에 저장된 수면 데이터 기준")
                    .font(.system(size: 11 * scale, weight: .regular))
                    .foregroundStyle(ReportColor.text)
                    .padding(.top, 12 * scale)
            }

            reportSleepStageBar(sleep: sleep, scale: scale)
                .padding(.top, 16 * scale)

            HStack(spacing: 0) {
                stageDurationText("얕은 수면", minutes: sleep?.coreMinutes ?? 0, scale: scale)
                Spacer()
                stageDurationText("깊은 수면", minutes: sleep?.deepMinutes ?? 0, scale: scale)
                Spacer()
                stageDurationText("REM", minutes: sleep?.remMinutes ?? 0, scale: scale)
                Spacer()
                stageDurationText("비수면", minutes: sleep?.awakeMinutes ?? 0, scale: scale)
            }
            .padding(.top, 11 * scale)

            Text("심박 변이도 \(hrvText)")
                .font(.system(size: 11 * scale, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.top, 18 * scale)

            if !hasSleep {
                Text("표시할 수면 데이터가 없어요")
                    .font(.system(size: 11 * scale, weight: .regular))
                    .foregroundStyle(ReportColor.muted)
                    .padding(.top, 8 * scale)
            }
        }
        .padding(16 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 146 * scale)
        .background(ReportColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        }
    }

    private func reportSleepStageBar(sleep: HistoryDaySleepSummary?, scale: CGFloat) -> some View {
        HistorySleepStageTimelineBar(segments: sleep?.stageSegments ?? [], height: 14 * scale)
    }

    private func stageDurationText(_ title: String, minutes: Int, scale: CGFloat) -> some View {
        Text("\(title)  \(durationText(minutes))")
            .font(.system(size: 9 * scale, weight: .regular))
            .foregroundStyle(ReportColor.muted)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }

    private func pvtCard(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("평균 반응 \(averagePVTText) · Lapse \(averageLapseText) · False Start \(falseStartTotal)")
                .font(.system(size: 12 * scale, weight: .regular))
                .foregroundStyle(ReportColor.text)

            ReportPVTTrendChart(evaluations: state.sortedEvaluations)
                .frame(height: 60 * scale)
                .padding(.top, 12 * scale)

            HStack {
                tableHeader("시간", scale: scale)
                    .frame(maxWidth: .infinity, alignment: .leading)
                tableHeader("평균 RT", scale: scale)
                    .frame(width: 76 * scale, alignment: .leading)
                tableHeader("Lapse", scale: scale)
                    .frame(width: 56 * scale, alignment: .center)
                tableHeader("ROI", scale: scale)
                    .frame(width: 38 * scale, alignment: .trailing)
            }
            .padding(.top, 20 * scale)

            VStack(spacing: 10 * scale) {
                ForEach(state.sortedEvaluations) { evaluation in
                    reportPVTRow(evaluation, scale: scale)
                }
            }
            .padding(.top, 12 * scale)
        }
        .padding(16 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReportColor.card)
        .clipShape(RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        }
    }

    private func tableHeader(_ text: String, scale: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 10 * scale, weight: .bold))
            .foregroundStyle(ReportColor.muted)
    }

    private func reportPVTRow(_ evaluation: HistoryDayEvaluation, scale: CGFloat) -> some View {
        let status = ReportROIStatus(score: evaluation.finalScore)

        return HStack {
            Text("\(timeText(evaluation.measuredAt)) · \(dayPartText(evaluation.measuredAt))")
                .font(.system(size: 12 * scale, weight: .regular))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(evaluation.pvt.averageMilliseconds)ms")
                .font(.system(size: 12 * scale, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: 76 * scale, alignment: .leading)

            Text(String(evaluation.pvt.lapseCount))
                .font(.system(size: 12 * scale, weight: .regular))
                .foregroundStyle(.white)
                .frame(width: 56 * scale, alignment: .center)

            Text(String(evaluation.finalScore))
                .font(.system(size: 12 * scale, weight: .bold))
                .foregroundStyle(status.color)
                .frame(width: 38 * scale, alignment: .trailing)
        }
    }

    private func footer(scale: CGFloat) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 7 * scale) {
                HStack(spacing: 8 * scale) {
                    Text("⚡")
                        .font(.system(size: 13 * scale, weight: .bold))
                        .foregroundStyle(Color(red: 1, green: 0.82, blue: 0.2))
                    Text("bryki")
                        .font(.system(size: 14 * scale, weight: .heavy))
                        .foregroundStyle(.white)
                }

                Text("\(fileNameText) · 1/1 페이지 · 생성 \(createdAtText)")
                    .font(.system(size: 9 * scale, weight: .regular))
                    .foregroundStyle(ReportColor.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer()

            if let appIcon = Bundle.main.primaryAppIconImage {
                Image(uiImage: appIcon)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 42 * scale, height: 42 * scale)
                    .clipShape(RoundedRectangle(cornerRadius: 10 * scale, style: .continuous))
            } else {
                Text("앱 아이콘")
                    .font(.system(size: 12 * scale, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }

    private var averagePVTText: String {
        let values = state.evaluations.map(\.pvt.averageMilliseconds)
        guard !values.isEmpty else { return "데이터 없음" }
        return "\(Int((Double(values.reduce(0, +)) / Double(values.count)).rounded()))ms"
    }

    private var averageLapseText: String {
        guard !state.evaluations.isEmpty else { return "0회" }
        let values = state.evaluations.map(\.pvt.lapseCount)
        let average = Double(values.reduce(0, +)) / Double(values.count)
        return "\(Int(average.rounded()))회"
    }

    private var falseStartTotal: Int {
        state.evaluations.map(\.pvt.falseStartCount).reduce(0, +)
    }

    private var hrvText: String {
        guard let nightHrvMs = state.sleep?.nightHrvMs else {
            return "--ms"
        }

        guard let baseline = state.sleep?.weeklyHrvBaselineMs,
              baseline > 0 else {
            return String(format: "%.0fms", nightHrvMs)
        }

        let ratio = Int(((nightHrvMs / baseline) * 100).rounded())
        return String(format: "%.0fms · 기준 %d%%", nightHrvMs, ratio)
    }

    private var appVersionText: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var fileNameText: String {
        "report-\(fileDateText(state.selectedDate))-\(profileSnapshot.name).pdf"
    }

    private var createdAtText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter.string(from: Date())
    }

    private func sleepTimeSummaryText(
        sleep: HistoryDaySleepSummary,
        bedStartAt: Date,
        bedEndAt: Date
    ) -> String {
        let range = "입면 \(timeText(bedStartAt)) · 기상 \(timeText(bedEndAt))"
        guard let efficiency = sleep.efficiencyPercent else {
            return range
        }
        return "효율 \(efficiency)% · \(range)"
    }

    private func durationText(_ minutes: Int?) -> String {
        guard let minutes, minutes > 0 else { return "데이터 없음" }
        return durationText(minutes)
    }

    private func durationText(_ minutes: Int) -> String {
        if minutes <= 0 {
            return "0m"
        }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    private func reportDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy.MM.dd (E)"
        return formatter.string(from: date)
    }

    private func fileDateText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func dayPartText(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        let hour = calendar.component(.hour, from: date)

        switch hour {
        case 5..<12:
            return "오전"
        case 12..<18:
            return "오후"
        default:
            return "야간"
        }
    }
}

private struct ReportPDFItem: Identifiable {
    let url: URL

    var id: String { url.absoluteString }
}

private struct ReportActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct ReportPVTTrendChart: View {
    let evaluations: [HistoryDayEvaluation]

    var body: some View {
        GeometryReader { proxy in
            let chartItems = chartItems(size: proxy.size)
            let points = chartItems.map(\.point)

            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(ReportColor.background.opacity(0.78))

                if points.count > 1 {
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(ReportColor.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }

                ForEach(Array(chartItems.enumerated()), id: \.offset) { _, item in
                    Text("\(item.averageMilliseconds)ms")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .position(
                            x: item.point.x,
                            y: max(10, item.point.y - 13)
                        )

                    Circle()
                        .fill(ReportColor.accent)
                        .frame(width: 8, height: 8)
                        .overlay {
                            Circle()
                                .stroke(.white, lineWidth: 2)
                        }
                        .position(item.point)
                }
            }
        }
    }

    private func chartItems(size: CGSize) -> [(point: CGPoint, averageMilliseconds: Int)] {
        let sorted = evaluations.sorted { $0.measuredAt < $1.measuredAt }
        guard !sorted.isEmpty else { return [] }

        let horizontalPadding: CGFloat = sorted.count == 1 ? size.width / 2 : 28
        let usableWidth = max(1, size.width - horizontalPadding * 2)
        let usableHeight = max(1, size.height - 34)
        let minValue = max(0, (sorted.map(\.pvt.averageMilliseconds).min() ?? 0) - 20)
        let maxValue = min(600, (sorted.map(\.pvt.averageMilliseconds).max() ?? 500) + 20)
        let range = max(1, maxValue - minValue)

        return sorted.enumerated().map { index, evaluation in
            let x: CGFloat
            if sorted.count == 1 {
                x = horizontalPadding
            } else {
                x = horizontalPadding + usableWidth * CGFloat(index) / CGFloat(sorted.count - 1)
            }
            let normalized = CGFloat(evaluation.pvt.averageMilliseconds - minValue) / CGFloat(range)
            let y = 20 + usableHeight * normalized
            return (CGPoint(x: x, y: y), evaluation.pvt.averageMilliseconds)
        }
    }
}

private enum ReportROIStatus {
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

    var reportTitle: String {
        switch self {
        case .excellent:
            return "최적의 방전 상태"
        case .stable:
            return "안정적인 방전 상태"
        case .caution:
            return "주의가 필요한 상태"
        case .low:
            return "회복이 필요한 상태"
        }
    }

    var color: Color {
        switch self {
        case .excellent, .stable:
            return Color(red: 0.063, green: 0.725, blue: 0.506)
        case .caution:
            return Color(red: 0.961, green: 0.62, blue: 0.043)
        case .low:
            return Color(red: 1, green: 0.267, blue: 0.267)
        }
    }
}

private extension Bundle {
    var primaryAppIconImage: UIImage? {
        guard let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String] else {
            return UIImage(named: "AppIcon-1024")
        }

        return iconFiles
            .reversed()
            .compactMap { UIImage(named: $0) }
            .first ?? UIImage(named: "AppIcon-1024")
    }
}

private enum ReportColor {
    static let background = Color(red: 0.039, green: 0.055, blue: 0.153)
    static let card = Color(red: 0.078, green: 0.098, blue: 0.216)
    static let footer = Color(red: 0.058, green: 0.075, blue: 0.18)
    static let text = Color(red: 0.7, green: 0.72, blue: 0.82)
    static let muted = Color(red: 0.45, green: 0.47, blue: 0.6)
    static let accent = Color(red: 0.133, green: 0.827, blue: 0.933)
    static let deep = Color(red: 0.486, green: 0.361, blue: 1)
    static let rem = Color(red: 0.961, green: 0.62, blue: 0.043)
    static let awake = Color(red: 1, green: 0.267, blue: 0.267)

    static let gradient = LinearGradient(
        colors: [
            Color(red: 0.486, green: 0.361, blue: 1),
            Color(red: 0.133, green: 0.831, blue: 0.929)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )
}

private extension HistoryDaySleepStageKind {
    var reportColor: Color {
        switch self {
        case .core:
            return ReportColor.accent
        case .deep:
            return ReportColor.deep
        case .rem:
            return ReportColor.rem
        case .awake:
            return ReportColor.awake
        case .unclassified:
            return ReportColor.accent.opacity(0.45)
        }
    }
}
