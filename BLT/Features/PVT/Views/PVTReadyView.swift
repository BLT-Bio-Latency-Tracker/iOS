import SwiftUI

struct PVTReadyView: View {
    private enum Step {
        case ready
        case calibration
    }

    let onClose: () -> Void
    let onComplete: (PVTSummary) -> Void
    let onAbort: () -> Void

    @State private var step: Step = .ready

    private let designWidth: CGFloat = 390

    var body: some View {
        ZStack {
            switch step {
            case .ready:
                readyContent

            case .calibration:
                PVTEnvironmentCalibrationView(
                    onClose: {
                        step = .ready
                    },
                    onComplete: onComplete,
                    onAbort: onAbort
                )
                .ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var readyContent: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / designWidth
            let contentWidth = max(0, proxy.size.width - 40 * scale)
            let horizontalInset = (proxy.size.width - contentWidth) / 2
            let topPadding = max(36 * scale, 60 * scale - proxy.safeAreaInsets.top)

            ZStack {
                Color.pvtReadyBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header(scale: scale)
                        .padding(.top, topPadding)

                    Spacer(minLength: 0)

                    VStack(spacing: 0) {
                        lightningGraphic(scale: scale)

                        Text("30초 반응 속도 테스트")
                            .font(.system(size: 24 * scale, weight: .bold))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.top, 40 * scale)

                        Text("화면에 점이 나타나면 최대한 빠르게 탭하세요")
                            .font(.system(size: 13 * scale, weight: .regular))
                            .foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .padding(.top, 10 * scale)

                        instructionCard(scale: scale)
                            .padding(.top, 43 * scale)
                    }

                    Spacer(minLength: 0)

                    Button {
                        step = .calibration
                    } label: {
                        Text("시작하기")
                            .font(.system(size: 16 * scale, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56 * scale)
                            .background(
                                LinearGradient(
                                    colors: [Color.pvtReadyPrimary, Color.pvtReadyCyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, max(28 * scale, 34 * scale - proxy.safeAreaInsets.bottom))
                }
                .padding(.horizontal, horizontalInset)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func header(scale: CGFloat) -> some View {
        ZStack {
            Text("PVT 측정 · 1/2")
                .font(.system(size: 14 * scale, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)

            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 24 * scale, weight: .regular))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(width: 36 * scale, height: 36 * scale)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .frame(height: 36 * scale)
    }

    private func lightningGraphic(scale: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.pvtReadyPrimary.opacity(0.18))
                .frame(width: 200 * scale, height: 200 * scale)
                .blur(radius: 32 * scale)

            Circle()
                .fill(Color.pvtReadyPrimary.opacity(0.08))
                .frame(width: 148 * scale, height: 148 * scale)
                .blur(radius: 20 * scale)

            Circle()
                .fill(Color.pvtReadyPrimary)
                .frame(width: 60 * scale, height: 60 * scale)

            Text("⚡")
                .font(.system(size: 30 * scale, weight: .regular))
                .frame(width: 60 * scale, height: 30 * scale)
        }
        .accessibilityHidden(true)
    }

    private func instructionCard(scale: CGFloat) -> some View {
        VStack(spacing: 16 * scale) {
            instructionRow(index: 1, text: "조용하고 밝은 환경에서 진행하세요", scale: scale)
            instructionRow(index: 2, text: "기기를 안정적인 곳에 두고 양손으로 잡으세요", scale: scale)
            instructionRow(index: 3, text: "점이 보이는 즉시 화면을 탭합니다", scale: scale)
            instructionRow(index: 4, text: "약 30초 정도 소요됩니다", scale: scale)
        }
        .padding(.horizontal, 16 * scale)
        .frame(maxWidth: .infinity)
        .frame(height: 180 * scale)
        .background(Color.pvtReadyCard)
        .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16 * scale, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func instructionRow(index: Int, text: String, scale: CGFloat) -> some View {
        HStack(spacing: 12 * scale) {
            Text("\(index)")
                .font(.system(size: 11 * scale, weight: .bold))
                .foregroundStyle(Color.pvtReadyPrimary)
                .frame(width: 22 * scale, height: 22 * scale)
                .background(Color.pvtReadyPrimary.opacity(0.2))
                .clipShape(Circle())

            Text(text)
                .font(.system(size: 12 * scale, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 0)
        }
    }
}

private extension Color {
    static let pvtReadyBackground = Color(red: 0.039, green: 0.055, blue: 0.153)
    static let pvtReadyCard = Color(red: 0.078, green: 0.098, blue: 0.216)
    static let pvtReadyPrimary = Color(red: 0.486, green: 0.361, blue: 1)
    static let pvtReadyCyan = Color(red: 0.133, green: 0.831, blue: 0.929)
}
