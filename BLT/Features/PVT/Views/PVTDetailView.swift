import Charts
import SwiftUI

struct PVTDetailView: View {
    @StateObject private var viewModel: PVTDetailViewModel

    let onBack: () -> Void

    private let designWidth: CGFloat = 390

    init(summary: PVTSummary?, onBack: @escaping () -> Void) {
        self.onBack = onBack
        _viewModel = StateObject(wrappedValue: PVTDetailViewModel(summary: summary))
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / designWidth
            let contentWidth = max(0, proxy.size.width - 40 * scale)
            let horizontalInset = (proxy.size.width - contentWidth) / 2
            let topPadding = max(8 * scale, 56 * scale - proxy.safeAreaInsets.top)

            ZStack {
                Color.pvtDetailBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        header(scale: scale)
                            .padding(.top, topPadding)

                        summarySection(scale: scale)
                            .padding(.top, 25 * scale)

                        statCards(scale: scale)
                            .padding(.top, 15 * scale)

                        trialDistributionSection(scale: scale)
                            .padding(.top, 28 * scale)

                        metricsSection(scale: scale)
                            .padding(.top, 26 * scale)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, horizontalInset)
                    .padding(.bottom, 34 * scale)
                    .frame(minHeight: proxy.size.height)
                }
            }
        }
        .preferredColorScheme(.dark)
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

    private func summarySection(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("오늘의 PVT 결과")
                .font(.system(size: 12 * scale, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))

            HStack(alignment: .lastTextBaseline, spacing: 10 * scale) {
                Text("\(viewModel.state.averageMilliseconds)")
                    .font(.system(size: 44 * scale, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("ms 평균")
                    .font(.system(size: 13 * scale, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.bottom, 8 * scale)
            }
            .padding(.top, 3 * scale)
        }
    }

    private func statCards(scale: CGFloat) -> some View {
        HStack(spacing: 16 * scale) {
            statCard(
                title: "BEST",
                value: "\(viewModel.state.bestMilliseconds)",
                suffix: "ms",
                valueColor: Color.pvtDetailPositive,
                scale: scale
            )

            statCard(
                title: "LAPSE",
                value: "\(viewModel.state.lapseCount)",
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

            HStack(alignment: .lastTextBaseline, spacing: 6 * scale) {
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
            .padding(.top, 16 * scale)
        }
        .padding(.horizontal, 16 * scale)
        .padding(.top, 14 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 80 * scale)
        .background(Color.pvtDetailCard)
        .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func trialDistributionSection(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Trial 분포")
                .font(.system(size: 12 * scale, weight: .semibold))
                .tracking(0.5 * scale)
                .foregroundStyle(.white.opacity(0.85))

            ZStack(alignment: .bottomLeading) {
                Chart {
                    RuleMark(y: .value("기준선", 350))
                        .foregroundStyle(.white.opacity(0.15))
                        .lineStyle(StrokeStyle(lineWidth: 1 * scale))

                    ForEach(viewModel.state.trials) { point in
                        PointMark(
                            x: .value("Trial", point.index),
                            y: .value("반응 시간", chartMilliseconds(point.milliseconds))
                        )
                        .foregroundStyle(point.isFasterThanBaseline ? Color.pvtDetailPositive : Color.pvtDetailCaution)
                        .symbolSize(90 * scale)
                    }
                }
                .chartXScale(domain: 0.5...7.5)
                .chartYScale(domain: 200...520)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .padding(.horizontal, 16 * scale)
                .padding(.top, 18 * scale)
                .padding(.bottom, 25 * scale)

                Text("350ms 기준선")
                    .font(.system(size: 10 * scale, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.leading, 16 * scale)
                    .padding(.bottom, 17 * scale)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140 * scale)
            .background(Color.pvtDetailCard)
            .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14 * scale, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
            .padding(.top, 14 * scale)
        }
    }

    private func metricsSection(scale: CGFloat) -> some View {
        VStack(spacing: 8 * scale) {
            metricRow(
                title: "False Start",
                value: "\(viewModel.state.falseStartCount)회",
                valueColor: .white,
                scale: scale
            )
            metricRow(
                title: "응답 안정성",
                value: viewModel.state.responseStability.title,
                valueColor: color(for: viewModel.state.responseStability),
                scale: scale
            )
            metricRow(
                title: "각성 수준",
                value: viewModel.state.arousalLevel.title,
                valueColor: color(for: viewModel.state.arousalLevel),
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
                .font(.system(size: 13 * scale, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            Spacer()

            Text(value)
                .font(.system(size: 14 * scale, weight: .bold))
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, 16 * scale)
        .frame(maxWidth: .infinity)
        .frame(height: 44 * scale)
        .background(Color.pvtDetailCard)
        .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func chartMilliseconds(_ milliseconds: Int) -> Int {
        min(max(milliseconds, 200), 520)
    }

    private func color(for status: PVTDetailStatus) -> Color {
        switch status {
        case .good:
            return Color.pvtDetailPositive
        case .caution:
            return Color.pvtDetailCaution
        case .poor:
            return Color.pvtDetailNegative
        }
    }
}

private extension Color {
    static let pvtDetailBackground = Color(red: 0.039, green: 0.055, blue: 0.153)
    static let pvtDetailCard = Color(red: 0.078, green: 0.098, blue: 0.216)
    static let pvtDetailPositive = Color(red: 0.063, green: 0.725, blue: 0.506)
    static let pvtDetailCaution = Color(red: 0.961, green: 0.62, blue: 0.043)
    static let pvtDetailNegative = Color(red: 0.937, green: 0.267, blue: 0.267)
}
