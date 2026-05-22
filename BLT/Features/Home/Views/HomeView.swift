import SwiftUI
import Combine

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    var onPVTStart: () -> Void = {}

    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private let designWidth: CGFloat = 390
    private let designHeight: CGFloat = 844

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / designWidth
            let contentWidth = max(0, proxy.size.width - 40)
            let horizontalInset = (proxy.size.width - contentWidth) / 2
            let headerTopPadding = max(30 * scale, 68 * scale - proxy.safeAreaInsets.top)

            ZStack {
                Color.bltBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        header(scale: scale)
                            .padding(.top, headerTopPadding)
                            .padding(.horizontal, 4 * scale)

                        roiSummary(scale: scale)
                            .padding(.top, 27 * scale)
                            .padding(.horizontal, 9 * scale)

                        recommendationSection(scale: scale)
                            .padding(.top, 13 * scale)
                            .padding(.horizontal, 1 * scale)

                        pvtStartButton(scale: scale)
                            .padding(.top, 34 * scale)
                            .padding(.bottom, max(36, 36 * scale))
                    }
                    .padding(.horizontal, horizontalInset)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .preferredColorScheme(.dark)
        .onReceive(timer) { date in
            viewModel.updateCurrentDate(date)
        }
    }

    private func header(scale: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 4 * scale) {
                Text(viewModel.greetingText)
                    .font(.system(size: 13 * scale, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))

                Text("\(viewModel.state.userName)님")
                    .font(.system(size: 22 * scale, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8 * scale) {
                Button {} label: {
                    Text("🔔")
                        .font(.system(size: 20 * scale))
                        .frame(width: 36 * scale, height: 36 * scale)
                        .background(Color.bltCard)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Button {} label: {
                    Text(viewModel.state.profileInitial)
                        .font(.system(size: 20 * scale, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36 * scale, height: 36 * scale)
                        .background(Color.bltPrimary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func roiSummary(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10 * scale) {
            HStack(spacing: 8 * scale) {
                Circle()
                    .fill(Color.bltPositive)
                    .frame(width: 8 * scale, height: 8 * scale)

                Text("BRAIN ROI")
                    .font(.system(size: 10 * scale, weight: .semibold))
                    .tracking(0.6 * scale)
                    .foregroundStyle(Color.bltMutedText)

                Text("\(viewModel.state.brainROI)")
                    .font(.system(size: 14 * scale, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.leading, 4 * scale)

                Text("· \(viewModel.state.roiStatusText)")
                    .font(.system(size: 11 * scale, weight: .regular))
                    .foregroundStyle(Color.bltMutedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 8 * scale)

                Text("▲ \(viewModel.state.roiChangePercent)%")
                    .font(.system(size: 13 * scale, weight: .semibold))
                    .foregroundStyle(Color.bltPositive)
                    .lineLimit(1)
            }
            .padding(.horizontal, 20 * scale)
            .frame(maxWidth: .infinity)
            .frame(height: 36 * scale)
            .background(Color.bltCard)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.bltBorder, lineWidth: 1)
            }

            Text(viewModel.measurementSummaryText)
                .font(.system(size: 10 * scale, weight: .regular))
                .foregroundStyle(Color.bltSubtleText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .padding(.leading, 12 * scale)
        }
    }

    private func recommendationSection(scale: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.bltPrimary.opacity(0.18))
                .frame(width: 180 * scale, height: 180 * scale)
                .offset(x: -172 * scale, y: -12 * scale)

            Circle()
                .fill(Color.bltCyan.opacity(0.12))
                .frame(width: 160 * scale, height: 160 * scale)
                .offset(x: 142 * scale, y: 226 * scale)

            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text("TODAY'S RECOMMENDATION")
                        .font(.system(size: 10 * scale, weight: .semibold))
                        .tracking(1.2 * scale)
                        .foregroundStyle(Color.bltMutedText)

                    Spacer()

                    Button {} label: {
                        HStack(spacing: 2 * scale) {
                            Text("상세 분석")
                            Text("›")
                                .font(.system(size: 13 * scale, weight: .medium))
                        }
                        .font(.system(size: 13 * scale, weight: .medium))
                        .foregroundStyle(Color.bltCyan)
                    }
                    .buttonStyle(.plain)
                }

                TimelineBarView(
                    segments: viewModel.state.timelineSegments,
                    progress: viewModel.currentTimeProgress,
                    scale: scale
                )
                .frame(height: 76 * scale)
                .padding(.top, 10 * scale)

                Text(viewModel.state.recommendation.helperText)
                    .font(.system(size: 12 * scale, weight: .regular))
                    .foregroundStyle(Color.bltMutedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.top, 16 * scale)

                Text(viewModel.state.recommendation.title)
                    .font(.system(size: 29 * scale, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.top, 7 * scale)

                Text(viewModel.state.recommendation.description)
                    .font(.system(size: 14 * scale, weight: .regular))
                    .foregroundStyle(Color.bltMutedText)
                    .lineSpacing(5 * scale)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8 * scale)

                Spacer(minLength: 24 * scale)

                nextRecommendationRow(scale: scale)
            }
            .padding(.horizontal, 20 * scale)
            .padding(.top, 22 * scale)
            .padding(.bottom, 22 * scale)
            .frame(maxWidth: .infinity)
            .frame(height: 320 * scale)
            .background(Color.bltCard)
            .clipShape(RoundedRectangle(cornerRadius: 24 * scale, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 24 * scale, style: .continuous)
                    .stroke(Color.bltBorder, lineWidth: 1)
            }
        }
    }

    private func nextRecommendationRow(scale: CGFloat) -> some View {
        Button {} label: {
            HStack(spacing: 14 * scale) {
                Text("NEXT")
                    .font(.system(size: 11 * scale, weight: .semibold))
                    .tracking(0.6 * scale)
                    .foregroundStyle(Color.bltSubtleText)
                    .frame(width: 48 * scale, alignment: .leading)

                Text("\(viewModel.state.nextRecommendation.timeRange)  ·  \(viewModel.state.nextRecommendation.title)")
                    .font(.system(size: 12 * scale, weight: .regular))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 8 * scale)

                Text("›")
                    .font(.system(size: 18 * scale, weight: .regular))
                    .foregroundStyle(Color.bltMutedText)
            }
            .padding(.horizontal, 14 * scale)
            .frame(maxWidth: .infinity)
            .frame(height: 40 * scale)
            .background(Color.bltBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12 * scale, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func pvtStartButton(scale: CGFloat) -> some View {
        Button(action: onPVTStart) {
            Text("⚡ 30초\nPVT 측정 시작")
                .font(.system(size: 32 * scale, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(8 * scale)
                .frame(maxWidth: .infinity)
                .frame(height: 161 * scale)
                .background(
                    LinearGradient(
                        colors: [Color.bltPrimary, Color.bltCyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct TimelineBarView: View {
    let segments: [HomeTimelineSegment]
    let progress: Double
    let scale: CGFloat

    private let startHour: Double = 6
    private let endHour: Double = 23

    var body: some View {
        VStack(spacing: 14 * scale) {
            GeometryReader { proxy in
                let markerX = proxy.size.width * progress
                let pinDiameter = 14 * scale
                let barTop = 24 * scale
                let pinCenterY = barTop - pinDiameter * 1.08

                ZStack {
                    HStack(spacing: 0) {
                        ForEach(segments) { segment in
                            segmentColor(segment.kind)
                                .frame(width: proxy.size.width * widthRatio(for: segment))
                        }
                    }
                    .frame(height: 36 * scale)
                    .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
                    .position(x: proxy.size.width / 2, y: barTop + 18 * scale)

                    Rectangle()
                        .fill(.white)
                        .frame(width: 4 * scale, height: 52 * scale)
                        .clipShape(Capsule())
                        .position(x: markerX, y: barTop + 14 * scale)

                    Circle()
                        .fill(.white)
                        .frame(width: pinDiameter, height: pinDiameter)
                        .overlay {
                            Circle()
                                .fill(Color.bltPrimary)
                                .frame(width: 8 * scale, height: 8 * scale)
                        }
                        .position(x: markerX, y: pinCenterY)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 56 * scale)

            GeometryReader { proxy in
                let labels: [Double] = [6, 9, 12, 16, 18, 23]

                ZStack(alignment: .leading) {
                    ForEach(labels, id: \.self) { hour in
                        timelineLabel(
                            formattedHour(hour),
                            isCurrent: currentRangeContains(hour),
                            scale: scale
                        )
                        .position(
                            x: proxy.size.width * boundaryProgress(hour),
                            y: 6 * scale
                        )
                    }
                }
            }
            .frame(height: 14 * scale)
        }
    }

    private func widthRatio(for segment: HomeTimelineSegment) -> Double {
        (segment.endHour - segment.startHour) / (endHour - startHour)
    }

    private func boundaryProgress(_ hour: Double) -> Double {
        (hour - startHour) / (endHour - startHour)
    }

    private func timelineLabel(_ text: String, isCurrent: Bool, scale: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 12 * scale, weight: isCurrent ? .semibold : .regular))
            .foregroundStyle(isCurrent ? .white : Color.bltMutedText)
            .lineLimit(1)
    }

    private func formattedHour(_ hour: Double) -> String {
        String(format: "%02d", Int(hour))
    }

    private func currentRangeContains(_ labelHour: Double) -> Bool {
        let labelProgress = boundaryProgress(labelHour)
        let nextBoundary: Double

        switch labelHour {
        case 6:
            nextBoundary = boundaryProgress(9)
        case 9:
            nextBoundary = boundaryProgress(12)
        case 12:
            nextBoundary = boundaryProgress(16)
        case 16:
            nextBoundary = boundaryProgress(18)
        case 18:
            nextBoundary = boundaryProgress(23)
        default:
            nextBoundary = 1
        }

        return progress >= labelProgress && progress < nextBoundary
    }

    private func segmentColor(_ kind: HomeTimelineSegmentKind) -> Color {
        switch kind {
        case .rest:
            return Color(red: 0.11, green: 0.133, blue: 0.29)
        case .deepWork:
            return Color.bltPrimary
        case .collaboration:
            return Color.bltPositive
        case .caution:
            return Color(red: 0.961, green: 0.62, blue: 0.043)
        case .recovery:
            return Color.bltCyan
        }
    }
}

private extension Color {
    static let bltBackground = Color(red: 0.039, green: 0.055, blue: 0.153)
    static let bltCard = Color(red: 0.078, green: 0.098, blue: 0.216)
    static let bltBorder = Color(red: 0.11, green: 0.133, blue: 0.29)
    static let bltPrimary = Color(red: 0.486, green: 0.361, blue: 1)
    static let bltCyan = Color(red: 0.133, green: 0.827, blue: 0.933)
    static let bltPositive = Color(red: 0.063, green: 0.722, blue: 0.506)
    static let bltMutedText = Color(red: 0.62, green: 0.66, blue: 0.82)
    static let bltSubtleText = Color(red: 0.42, green: 0.46, blue: 0.62)
}
