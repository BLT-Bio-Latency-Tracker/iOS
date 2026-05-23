import SwiftUI

struct PVTCalculationSplashView: View {
    let onComplete: () -> Void

    @State private var progress: CGFloat = 0
    @State private var messageIndex = 0
    @State private var didComplete = false

    private let designWidth: CGFloat = 390
    private let duration: TimeInterval = 4
    private let messageInterval: TimeInterval = 1
    private let messages = [
        CalculationMessage(text: "🛌 수면 데이터 로드 완료", color: Color.pvtCalculationMint),
        CalculationMessage(text: "⚡ PVT 분석 중...", color: .white.opacity(0.65)),
        CalculationMessage(text: "🧠 Brain ROI 계산 중...", color: .white.opacity(0.65)),
        CalculationMessage(text: "✨ 결과 화면 준비 중...", color: Color.pvtCalculationMint)
    ]

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / designWidth

            ZStack {
                Color.pvtCalculationBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    VStack(spacing: 0) {
                        calculationGraphic(scale: scale)

                        Text("Brain ROI 계산 중...")
                            .font(.system(size: 22 * scale, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.top, -20 * scale)

                        Text("수면 데이터와 PVT 결과를 분석하고 있어요.\n잠시만 기다려주세요.")
                            .font(.system(size: 13 * scale, weight: .regular))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .lineSpacing(4 * scale)
                            .padding(.top, 12 * scale)

                        progressBar(scale: scale)
                            .padding(.top, 38 * scale)

                        statusMessages(scale: scale)
                            .padding(.top, 32 * scale)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24 * scale)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            startLoading()
        }
        .onDisappear {
            didComplete = true
        }
    }

    private func calculationGraphic(scale: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.pvtCalculationViolet.opacity(0.15))
                .frame(width: 200 * scale, height: 200 * scale)
                .blur(radius: 32 * scale)

            Circle()
                .fill(Color.pvtCalculationViolet)
                .frame(width: 28 * scale, height: 28 * scale)
                .offset(x: -7 * scale, y: -8 * scale)

            Circle()
                .fill(Color.pvtCalculationCyan)
                .frame(width: 20 * scale, height: 20 * scale)
                .offset(x: 12 * scale, y: 8 * scale)
        }
        .accessibilityHidden(true)
    }

    private func progressBar(scale: CGFloat) -> some View {
        GeometryReader { proxy in
            let fillWidth = max(6 * scale, proxy.size.width * progress)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.1))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.pvtCalculationViolet, Color.pvtCalculationCyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth)
            }
        }
        .frame(width: 270 * scale, height: 6 * scale)
    }

    private func statusMessages(scale: CGFloat) -> some View {
        VStack(spacing: 11 * scale) {
            Text(messages[messageIndex].text)
                .font(.system(size: 12 * scale, weight: .medium))
                .foregroundStyle(messages[messageIndex].color)
                .multilineTextAlignment(.center)
                .id(messageIndex)
                .transition(.opacity.combined(with: .move(edge: .bottom)))

            let nextMessage = messages[(messageIndex + 1) % messages.count]
            Text(nextMessage.text)
                .font(.system(size: 12 * scale, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func startLoading() {
        progress = 0
        messageIndex = 0

        withAnimation(.linear(duration: duration)) {
            progress = 1
        }

        scheduleMessageRotation()

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            guard !didComplete else { return }
            didComplete = true
            onComplete()
        }
    }

    private func scheduleMessageRotation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + messageInterval) {
            guard !didComplete else { return }

            withAnimation(.easeInOut(duration: 0.25)) {
                messageIndex = (messageIndex + 1) % messages.count
            }

            scheduleMessageRotation()
        }
    }
}

private struct CalculationMessage {
    let text: String
    let color: Color
}

private extension Color {
    static let pvtCalculationBackground = Color(red: 0.039, green: 0.055, blue: 0.153)
    static let pvtCalculationViolet = Color(red: 0.486, green: 0.361, blue: 1)
    static let pvtCalculationCyan = Color(red: 0.133, green: 0.831, blue: 0.929)
    static let pvtCalculationMint = Color(red: 0.063, green: 0.725, blue: 0.506)
}
