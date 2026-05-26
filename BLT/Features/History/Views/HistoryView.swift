import SwiftUI

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()

    private let designWidth: CGFloat = 390

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / designWidth
            let contentWidth = max(0, proxy.size.width - 40 * scale)
            let horizontalInset = (proxy.size.width - contentWidth) / 2
            let topPadding = max(18 * scale, 36 * scale - proxy.safeAreaInsets.top)

            ZStack {
                Color.historyBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("History")
                            .font(.system(size: 22 * scale, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, topPadding)
                            .padding(.horizontal, 4 * scale)

                        monthSelector(scale: scale)
                            .padding(.top, 28 * scale)

                        calendarSection(scale: scale)
                            .padding(.top, 24 * scale)

                        legendSection(scale: scale)
                            .padding(.top, 22 * scale)
                            .padding(.horizontal, 4 * scale)

                        summarySection(scale: scale)
                            .padding(.top, 18 * scale)

                        Spacer(minLength: 24 * scale)
                    }
                    .padding(.horizontal, horizontalInset)
                    .padding(.bottom, 16 * scale)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .preferredColorScheme(.dark)
    }

    private func monthSelector(scale: CGFloat) -> some View {
        HStack {
            Button {
                viewModel.moveToPreviousMonth()
            } label: {
                Text("‹")
                    .font(.system(size: 22 * scale, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 44 * scale, height: 56 * scale)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(viewModel.monthTitle)
                .font(.system(size: 14 * scale, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            Button {
                viewModel.moveToNextMonth()
            } label: {
                Text("›")
                    .font(.system(size: 22 * scale, weight: .bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 44 * scale, height: 56 * scale)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8 * scale)
        .frame(maxWidth: .infinity)
        .frame(height: 56 * scale)
        .background(Color.historyCard)
        .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func calendarSection(scale: CGFloat) -> some View {
        VStack(spacing: 14 * scale) {
            HStack(spacing: 0) {
                ForEach(Array(["일", "월", "화", "수", "목", "금", "토"].enumerated()), id: \.offset) { index, title in
                    Text(title)
                        .font(.system(size: 11 * scale, weight: .semibold))
                        .foregroundStyle(weekdayColor(index))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 13 * scale)

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8 * scale), count: 7),
                spacing: 8 * scale
            ) {
                ForEach(viewModel.state.days) { day in
                    calendarDayCell(day, scale: scale)
                        .frame(height: 36 * scale)
                }
            }
        }
    }

    @ViewBuilder
    private func calendarDayCell(_ day: HistoryCalendarDay, scale: CGFloat) -> some View {
        if day.day == nil {
            Color.clear
        } else if day.hasRecord {
            VStack(spacing: 0) {
                Text("\(day.day ?? 0)")
                    .font(.system(size: 10 * scale, weight: .regular))
                    .foregroundStyle(Color.historyDeepText)
                    .frame(height: 13 * scale)

                Text("\(day.roiScore ?? 0)")
                    .font(.system(size: 13 * scale, weight: .bold))
                    .foregroundStyle(Color.historyDeepText)
                    .frame(height: 16 * scale)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36 * scale)
            .background(HistoryROILevel(score: day.roiScore).color)
            .clipShape(RoundedRectangle(cornerRadius: 8 * scale, style: .continuous))
            .overlay {
                if day.isToday {
                    RoundedRectangle(cornerRadius: 9 * scale, style: .continuous)
                        .stroke(Color.historyPrimary, lineWidth: 2 * scale)
                }
            }
        } else if day.isToday {
            VStack(spacing: 0) {
                Text("\(day.day ?? 0)")
                    .font(.system(size: 12 * scale, weight: .bold))
                    .foregroundStyle(Color.historyPrimary)
                    .frame(height: 15 * scale)

                Text("오늘")
                    .font(.system(size: 9 * scale, weight: .regular))
                    .foregroundStyle(Color.historyPrimary)
                    .frame(height: 11 * scale)

                Circle()
                    .fill(Color.historyPrimary)
                    .frame(width: 6 * scale, height: 6 * scale)
                    .padding(.top, 1 * scale)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36 * scale)
            .overlay {
                RoundedRectangle(cornerRadius: 10 * scale, style: .continuous)
                    .stroke(Color.historyPrimary, lineWidth: 2 * scale)
            }
        } else {
            VStack(spacing: 0) {
                Text("\(day.day ?? 0)")
                    .font(.system(size: 10 * scale, weight: .regular))
                    .foregroundStyle(Color.historyNoRecord)
                    .frame(height: 12 * scale)

                Circle()
                    .fill(Color.historyNoRecord)
                    .frame(width: 4 * scale, height: 4 * scale)
                    .padding(.top, 8 * scale)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 36 * scale)
        }
    }

    private func legendSection(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14 * scale) {
            Text("ROI 점수")
                .font(.system(size: 11 * scale, weight: .medium))
                .foregroundStyle(.white)

            HStack(spacing: 0) {
                legendItem(color: HistoryROILevel.excellent.color, text: "80+", squareSize: 14 * scale, scale: scale)
                    .frame(width: 82 * scale, alignment: .leading)

                legendItem(color: HistoryROILevel.good.color, text: "65~79", squareSize: 14 * scale, scale: scale)
                    .frame(width: 82 * scale, alignment: .leading)

                legendItem(color: HistoryROILevel.caution.color, text: "50~64", squareSize: 14 * scale, scale: scale)
                    .frame(width: 82 * scale, alignment: .leading)

                legendItem(color: HistoryROILevel.low.color, text: "~49", squareSize: 14 * scale, scale: scale)
            }

            HStack(spacing: 6 * scale) {
                Circle()
                    .fill(Color.historyNoRecord)
                    .frame(width: 6 * scale, height: 6 * scale)

                Text("측정 안 함")
                    .font(.system(size: 11 * scale, weight: .regular))
                    .foregroundStyle(Color.historyNoRecord)
            }
        }
    }

    private func legendItem(color: Color, text: String, squareSize: CGFloat, scale: CGFloat) -> some View {
        HStack(spacing: 6 * scale) {
            RoundedRectangle(cornerRadius: 4 * scale, style: .continuous)
                .fill(color)
                .frame(width: squareSize, height: squareSize)

            Text(text)
                .font(.system(size: 11 * scale, weight: .regular))
                .foregroundStyle(Color.historyLegendText)
                .lineLimit(1)
        }
    }

    private func summarySection(scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14 * scale) {
            Text("이번 달 통계")
                .font(.system(size: 12 * scale, weight: .semibold))
                .tracking(0.5 * scale)
                .foregroundStyle(.white.opacity(0.85))

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8 * scale),
                    GridItem(.flexible(), spacing: 8 * scale)
                ],
                spacing: 8 * scale
            ) {
                summaryCard(title: "측정 일수", value: measuredDaysText, scale: scale)
                summaryCard(title: "평균 ROI", value: summaryValue(viewModel.state.summary.averageROI), scale: scale)
                summaryCard(title: "최고 ROI", value: summaryValue(viewModel.state.summary.bestROI), scale: scale)
                summaryCard(title: "최저 ROI", value: summaryValue(viewModel.state.summary.lowestROI), scale: scale)
            }
        }
    }

    private func summaryCard(title: String, value: String, scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 5 * scale) {
            Text(title)
                .font(.system(size: 11 * scale, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))

            Text(value)
                .font(.system(size: value == "데이터 없음" ? 13 * scale : 16 * scale, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 16 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 56 * scale)
        .background(Color.historyCard)
        .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var measuredDaysText: String {
        let measuredDays = viewModel.state.summary.measuredDays
        return measuredDays > 0 ? "\(measuredDays)일" : "데이터 없음"
    }

    private func summaryValue(_ value: Int?) -> String {
        guard let value else { return "데이터 없음" }
        return "\(value)"
    }

    private func weekdayColor(_ index: Int) -> Color {
        if index == 0 {
            return Color.historyLow
        }
        if index == 6 {
            return Color.historyGood
        }
        return Color.historyLegendText
    }
}

private extension Color {
    static let historyBackground = Color(red: 0.039, green: 0.055, blue: 0.153)
    static let historyCard = Color(red: 0.078, green: 0.098, blue: 0.216)
    static let historyPrimary = Color(red: 0.486, green: 0.361, blue: 1)
    static let historyGood = Color(red: 0.133, green: 0.827, blue: 0.933)
    static let historyLow = Color(red: 0.937, green: 0.267, blue: 0.267)
    static let historyDeepText = Color(red: 0.039, green: 0.055, blue: 0.153)
    static let historyLegendText = Color(red: 0.7, green: 0.72, blue: 0.82)
    static let historyNoRecord = Color(red: 0.45, green: 0.47, blue: 0.6)
}
