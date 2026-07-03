import SwiftUI

struct PVTDetailView: View {
    @StateObject private var viewModel: PVTDetailViewModel
    @State private var selectedMeasurement: PVTDetailMeasurement?

    let onBack: () -> Void
    let onMeasurementDeleted: () -> Void

    private let designWidth: CGFloat = 390

    init(
        date: Date = Date(),
        onBack: @escaping () -> Void,
        onMeasurementDeleted: @escaping () -> Void = {}
    ) {
        self.onBack = onBack
        self.onMeasurementDeleted = onMeasurementDeleted
        _viewModel = StateObject(wrappedValue: PVTDetailViewModel(date: date))
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / designWidth
            let contentWidth = max(0, proxy.size.width - 40 * scale)
            let horizontalInset = (proxy.size.width - contentWidth) / 2
            let topPadding = max(0, 40 * scale - proxy.safeAreaInsets.top)

            ZStack {
                Color.pvtDetailBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header(scale: scale)
                        .padding(.top, topPadding)
                        .padding(.horizontal, horizontalInset)
                        .padding(.bottom, 22 * scale)
                        .background(Color.pvtDetailBackground)
                        .zIndex(1)

                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 0) {
                            if viewModel.state.isLoading {
                                loadingState(scale: scale)
                                    .padding(.top, 190 * scale)
                            } else if viewModel.state.hasMeasurements {
                                content(scale: scale)
                            } else {
                                emptyState(scale: scale)
                                    .padding(.top, 180 * scale)
                            }
                        }
                        .padding(.horizontal, horizontalInset)
                        .padding(.bottom, 34 * scale)
                        .frame(minHeight: proxy.size.height, alignment: .top)
                    }
                }
            }
        }
        .task {
            await viewModel.loadIfNeeded()
        }
        .preferredColorScheme(.dark)
        .enablesInteractivePopGesture()
        .navigationDestination(item: $selectedMeasurement) { measurement in
            PVTMeasurementDetailView(measurement: measurement) {
                selectedMeasurement = nil
            } onDeleted: {
                selectedMeasurement = nil
                await viewModel.reloadAfterDeletion()
                onMeasurementDeleted()
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func header(scale: CGFloat) -> some View {
        ZStack {
            Text("PVT 상세")
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

    private func content(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            summarySection(scale: scale)

            statCards(scale: scale)
                .padding(.top, 22 * scale)

            Text("PVT 검사 · \(viewModel.state.measurementCount)회 측정")
                .font(.system(size: 12 * scale, weight: .semibold))
                .tracking(1.3 * scale)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.top, 28 * scale)
                .padding(.leading, 8 * scale)

            trendCard(scale: scale)
                .padding(.top, 14 * scale)

            measurementList(scale: scale)
                .padding(.top, 20 * scale)
        }
    }

    private func summarySection(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("오늘의 PVT 결과")
                .font(.system(size: 12 * scale, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))

            HStack(alignment: .lastTextBaseline, spacing: 10 * scale) {
                Text(String(viewModel.state.averageMilliseconds))
                    .font(.system(size: 44 * scale, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("ms 평균")
                    .font(.system(size: 13 * scale, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
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
                value: String(viewModel.state.bestMilliseconds),
                suffix: "ms",
                valueColor: Color.pvtDetailPositive,
                scale: scale
            )

            statCard(
                title: "LAPSE",
                value: String(viewModel.state.averageLapseCount),
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
        .background(Color.pvtDetailCard)
        .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func trendCard(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("평균 반응 \(viewModel.state.averageMilliseconds)ms · Lapse \(viewModel.state.averageLapseCount)회 · False Start \(viewModel.state.averageFalseStartCount)")
                .font(.system(size: 12 * scale, weight: .regular))
                .foregroundStyle(.white.opacity(0.65))
                .padding(.top, 20 * scale)
                .padding(.horizontal, 16 * scale)

            PVTMeasurementLineChart(measurements: viewModel.state.measurements)
                .frame(height: 60 * scale)
                .padding(.horizontal, 16 * scale)
                .padding(.top, 16 * scale)

            measurementTable(scale: scale)
                .padding(.horizontal, 16 * scale)
                .padding(.top, 18 * scale)
                .padding(.bottom, 20 * scale)
        }
        .frame(maxWidth: .infinity)
        .background(Color.pvtDetailCard)
        .clipShape(RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func measurementTable(scale: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack {
                tableHeader("시간", alignment: .leading, scale: scale)
                    .frame(maxWidth: .infinity, alignment: .leading)
                tableHeader("평균 RT", alignment: .leading, scale: scale)
                    .frame(width: 70 * scale, alignment: .leading)
                tableHeader("Lapse", alignment: .center, scale: scale)
                    .frame(width: 52 * scale, alignment: .center)
                tableHeader("False Start", alignment: .center, scale: scale)
                    .frame(width: 70 * scale, alignment: .center)
            }

            ForEach(viewModel.state.measurements) { measurement in
                HStack {
                    Text("\(timeText(measurement.measuredAt)) · \(dayPartText(measurement.measuredAt))")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(measurement.averageMilliseconds)ms")
                        .frame(width: 70 * scale, alignment: .leading)
                    Text(String(measurement.lapseCount))
                        .frame(width: 52 * scale, alignment: .center)
                    Text(String(measurement.falseStartCount))
                        .frame(width: 70 * scale, alignment: .center)
                }
                .font(.system(size: 12 * scale, weight: .regular))
                .foregroundStyle(.white)
                .padding(.top, 16 * scale)
            }
        }
    }

    private func tableHeader(
        _ title: String,
        alignment: Alignment,
        scale: CGFloat
    ) -> some View {
        Text(title)
            .font(.system(size: 11 * scale, weight: .semibold))
            .foregroundStyle(.white.opacity(0.45))
            .frame(alignment: alignment)
    }

    private func measurementList(scale: CGFloat) -> some View {
        VStack(spacing: 12 * scale) {
            ForEach(viewModel.state.measurements) { measurement in
                measurementCard(measurement, scale: scale)
            }
        }
    }

    private func measurementCard(_ measurement: PVTDetailMeasurement, scale: CGFloat) -> some View {
        Button {
            selectedMeasurement = measurement
        } label: {
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 14 * scale) {
                        Text("\(timeText(measurement.measuredAt)) · \(dayPartText(measurement.measuredAt))")
                            .font(.system(size: 11 * scale, weight: .bold))
                            .foregroundStyle(.black.opacity(0.9))
                            .padding(.horizontal, 6 * scale)
                            .frame(height: 24 * scale)
                            .background(color(for: measurement.status))
                            .clipShape(Capsule())

                        Text("\(measurement.averageMilliseconds)ms")
                            .font(.system(size: 20 * scale, weight: .heavy))
                            .foregroundStyle(.white)
                    }

                    Text("평균 \(measurement.averageMilliseconds)ms · BEST \(measurement.bestMilliseconds ?? 0)ms · Lapse \(measurement.lapseCount)")
                        .font(.system(size: 12 * scale, weight: .regular))
                        .foregroundStyle(.white.opacity(0.62))
                        .padding(.top, 16 * scale)

                    Text("Trial \(measurement.totalCount)/\(measurement.totalCount) 완료 · False Start \(measurement.falseStartCount)")
                        .font(.system(size: 11 * scale, weight: .regular))
                        .foregroundStyle(.white.opacity(0.42))
                        .padding(.top, 4 * scale)
                }

                Spacer(minLength: 12 * scale)

                Text(measurement.status.title)
                    .font(.system(size: 12 * scale, weight: .bold))
                    .foregroundStyle(.black.opacity(0.9))
                    .frame(width: 52 * scale, height: 22 * scale)
                    .background(color(for: measurement.status))
                    .clipShape(Capsule())

                Image(systemName: "chevron.right")
                    .font(.system(size: 12 * scale, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.leading, 10 * scale)
            }
            .padding(.leading, 16 * scale)
            .padding(.trailing, 18 * scale)
            .frame(height: 88 * scale)
            .background(Color.pvtDetailCard)
            .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func loadingState(scale: CGFloat) -> some View {
        VStack(spacing: 14 * scale) {
            ProgressView()
                .tint(.white)
            Text("PVT 기록을 불러오는 중이에요")
                .font(.system(size: 13 * scale, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    private func emptyState(scale: CGFloat) -> some View {
        VStack(spacing: 14 * scale) {
            Text("⚡")
                .font(.system(size: 32 * scale))
                .frame(width: 72 * scale, height: 72 * scale)
                .background(Color.pvtDetailCard)
                .clipShape(Circle())

            Text(viewModel.state.errorMessage ?? "오늘 저장된 PVT 측정 기록이 없어요")
                .font(.system(size: 14 * scale, weight: .medium))
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func timeText(_ date: Date) -> String {
        Self.timeFormatter.string(from: date)
    }

    private func dayPartText(_ date: Date) -> String {
        let hour = Self.koreaCalendar.component(.hour, from: date)
        switch hour {
        case 5..<12:
            return "아침"
        case 12..<18:
            return "오후"
        default:
            return "야간"
        }
    }

    private func color(for status: PVTDetailStatus) -> Color {
        switch status {
        case .good:
            return Color.pvtDetailPositive
        case .caution:
            return Color.pvtDetailCyan
        case .poor:
            return Color.pvtDetailCaution
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static var koreaCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Seoul") ?? .current
        return calendar
    }
}

private struct PVTMeasurementLineChart: View {
    let measurements: [PVTDetailMeasurement]

    var body: some View {
        GeometryReader { proxy in
            let points = chartPoints(in: proxy.size)

            ZStack {
                Color.pvtDetailChartBackground

                if points.count >= 2 {
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                    }
                    .stroke(Color.pvtDetailCyan, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                }

                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(Color.pvtDetailCyan)
                        .overlay {
                            Circle()
                                .stroke(.white, lineWidth: 2)
                        }
                        .frame(width: 9, height: 9)
                        .position(point)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func chartPoints(in size: CGSize) -> [CGPoint] {
        guard !measurements.isEmpty else { return [] }

        let horizontalPadding: CGFloat = 28
        let verticalPadding: CGFloat = 12
        let chartWidth = max(1, size.width - horizontalPadding * 2)
        let chartHeight = max(1, size.height - verticalPadding * 2)
        let denominator = max(1, measurements.count - 1)

        return measurements.enumerated().map { index, measurement in
            let x = horizontalPadding + chartWidth * CGFloat(index) / CGFloat(denominator)
            let clamped = min(max(measurement.averageMilliseconds, 0), 500)
            let ratio = CGFloat(clamped) / 500
            let y = verticalPadding + chartHeight * (1 - ratio)
            return CGPoint(x: x, y: y)
        }
    }
}

private extension Color {
    static let pvtDetailBackground = Color(red: 0.039, green: 0.055, blue: 0.153)
    static let pvtDetailCard = Color(red: 0.078, green: 0.098, blue: 0.216)
    static let pvtDetailChartBackground = Color(red: 0.039, green: 0.055, blue: 0.153)
    static let pvtDetailPositive = Color(red: 0.063, green: 0.725, blue: 0.506)
    static let pvtDetailCyan = Color(red: 0.133, green: 0.827, blue: 0.933)
    static let pvtDetailCaution = Color(red: 0.961, green: 0.62, blue: 0.043)
}
