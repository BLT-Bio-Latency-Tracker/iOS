import SwiftUI
import UIKit

struct PVTCalculationCompleteView: View {
    let summary: PVTSummary
    let onShowResult: () -> Void

    @State private var sleepText = "--"
    @State private var iconScale: CGFloat = 0.68
    @State private var iconOpacity: Double = 0
    @State private var contentOpacity: Double = 0
    @State private var didRequestResult = false

    private let designWidth: CGFloat = 390
    private let healthKitService = HealthKitService()

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / designWidth

            ZStack {
                Color.pvtCompleteBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    VStack(spacing: 0) {
                        completeGraphic(scale: scale)

                        Text("측정 완료!")
                            .font(.system(size: 28 * scale, weight: .heavy))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.top, 30 * scale)

                        Text("오늘의 Brain ROI 점수를 확인해보세요.")
                            .font(.system(size: 14 * scale, weight: .regular))
                            .foregroundStyle(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .padding(.top, 10 * scale)

                        resultCards(scale: scale)
                            .padding(.top, 49 * scale)
                    }
                    .opacity(contentOpacity)

                    Spacer(minLength: 0)

                    Button {
                        guard !didRequestResult else { return }
                        didRequestResult = true
                        onShowResult()
                    } label: {
                        Text("결과 보기 →")
                            .font(.system(size: 16 * scale, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56 * scale)
                            .background(
                                LinearGradient(
                                    colors: [Color.pvtCompletePrimary, Color.pvtCompleteCyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(didRequestResult)
                    .padding(.bottom, max(28 * scale, 34 * scale - proxy.safeAreaInsets.bottom))
                }
                .padding(.horizontal, 20 * scale)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            playEntryAnimation()
        }
        .task {
            await loadSleepText()
        }
    }

    private func completeGraphic(scale: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.pvtCompleteMint.opacity(0.18))
                .frame(width: 240 * scale, height: 240 * scale)
                .blur(radius: 24 * scale)

            Circle()
                .fill(Color.pvtCompleteCyan.opacity(0.15))
                .frame(width: 180 * scale, height: 180 * scale)
                .blur(radius: 18 * scale)

            Circle()
                .fill(Color.pvtCompletePrimary)
                .frame(width: 100 * scale, height: 100 * scale)
                .shadow(color: Color.pvtCompletePrimary.opacity(0.34), radius: 22 * scale, x: 0, y: 12 * scale)

            Text("✨")
                .font(.system(size: 56 * scale, weight: .regular))
                .frame(width: 100 * scale, height: 56 * scale)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
        }
        .accessibilityHidden(true)
    }

    private func resultCards(scale: CGFloat) -> some View {
        HStack(spacing: 16 * scale) {
            resultCard(
                title: "PVT 평균",
                value: pvtAverageText,
                valueColor: Color.pvtCompleteCyan,
                scale: scale
            )

            resultCard(
                title: "수면",
                value: sleepText,
                valueColor: Color.pvtCompletePrimary,
                scale: scale
            )
        }
    }

    private func resultCard(title: String, value: String, valueColor: Color, scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8 * scale) {
            Text(title)
                .font(.system(size: 11 * scale, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))

            Text(value)
                .font(.system(size: 22 * scale, weight: .heavy))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 80 * scale)
        .padding(.horizontal, 16 * scale)
        .background(Color.pvtCompleteCard)
        .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private var pvtAverageText: String {
        guard let averageMilliseconds = summary.averageMilliseconds else {
            return "--ms"
        }
        return "\(averageMilliseconds)ms"
    }

    private func playEntryAnimation() {
        withAnimation(.easeOut(duration: 0.22)) {
            contentOpacity = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.38) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        withAnimation(.spring(response: 0.52, dampingFraction: 0.66).delay(0.38)) {
            iconScale = 1
            iconOpacity = 1
        }
    }

    @MainActor
    private func loadSleepText() async {
        do {
            let resolvedSleep = try await healthKitService.fetchDisplaySleepSummary(for: Date())

            switch resolvedSleep.status {
            case .available:
                sleepText = durationText(from: resolvedSleep.summary?.totalMinutes ?? 0)
            case .noSleep:
                sleepText = "0h"
            case .syncing, .noWearableData, .notConnected:
                sleepText = "--"
            }
        } catch {
            sleepText = "--"
        }
    }

    private func durationText(from minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }
}

private extension Color {
    static let pvtCompleteBackground = Color(red: 0.039, green: 0.055, blue: 0.153)
    static let pvtCompleteCard = Color(red: 0.078, green: 0.098, blue: 0.216)
    static let pvtCompletePrimary = Color(red: 0.486, green: 0.361, blue: 1)
    static let pvtCompleteCyan = Color(red: 0.133, green: 0.831, blue: 0.929)
    static let pvtCompleteMint = Color(red: 0.063, green: 0.725, blue: 0.506)
}
