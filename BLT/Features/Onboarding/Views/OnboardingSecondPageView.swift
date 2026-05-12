import SwiftUI

struct OnboardingSecondPageView: View {
    var onNext: () -> Void = {}
    var onSkip: () -> Void = {}

    private let designWidth: CGFloat = 375
    private let designHeight: CGFloat = 812

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / designWidth, proxy.size.height / designHeight)
            let horizontalInset = max(24, (proxy.size.width - 327 * scale) / 2)

            ZStack {
                Color(red: 0.039, green: 0.055, blue: 0.153)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header(scale: scale)
                        .padding(.top, 64 * scale)
                        .padding(.horizontal, horizontalInset)

                    sleepPVTGraphic(size: 255 * scale)
                        .padding(.top, 51 * scale)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("수면과 30초 반응속도로\n당신의 뇌를 측정합니다")
                            .font(.system(size: 26 * scale, weight: .heavy))
                            .foregroundStyle(.white)
                            .lineSpacing(6 * scale)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Apple Health의 수면 데이터와\nPVT 검사를 결합해 정확하게")
                            .font(.system(size: 14 * scale, weight: .regular))
                            .foregroundStyle(.white.opacity(0.65))
                            .lineSpacing(6 * scale)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 28 * scale)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, horizontalInset)
                    .padding(.top, 45 * scale)

                    Spacer(minLength: 0)

                    pageIndicator
                        .padding(.bottom, 20 * scale)

                    Button(action: onNext) {
                        Text("다음")
                            .font(.system(size: 16 * scale, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52 * scale)
                            .background(Color(red: 0.486, green: 0.361, blue: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, horizontalInset)
                    .padding(.bottom, max(32, 32 * scale))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .preferredColorScheme(.dark)
    }

    private func header(scale: CGFloat) -> some View {
        HStack {
            Text("2 / 3")
                .font(.system(size: 12 * scale, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))

            Spacer()

            Button(action: onSkip) {
                Text("건너뛰기")
                    .font(.system(size: 13 * scale, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
    }

    private func sleepPVTGraphic(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.141, green: 0.545, blue: 0.675).opacity(0.48),
                            Color(red: 0.091, green: 0.257, blue: 0.475).opacity(0.24),
                            .clear
                        ],
                        center: .center,
                        startRadius: 12,
                        endRadius: size * 0.52
                    )
                )
                .blur(radius: 10)
                .frame(width: size, height: size)

            HStack(alignment: .bottom, spacing: 8 * size / 255) {
                roundedBar(width: 14 * size / 255, height: 50 * size / 255, color: Color(red: 0.133, green: 0.827, blue: 0.933).opacity(0.7))
                roundedBar(width: 14 * size / 255, height: 70 * size / 255, color: Color(red: 0.133, green: 0.827, blue: 0.933).opacity(0.85))
                roundedBar(width: 14 * size / 255, height: 92 * size / 255, color: Color(red: 0.486, green: 0.361, blue: 1))
                roundedBar(width: 14 * size / 255, height: 72 * size / 255, color: Color(red: 0.486, green: 0.361, blue: 1).opacity(0.85))
                roundedBar(width: 14 * size / 255, height: 46 * size / 255, color: Color(red: 0.133, green: 0.827, blue: 0.933).opacity(0.7))
            }
            .frame(width: size, height: size, alignment: .center)
            .offset(x: -55 * size / 255, y: -8 * size / 255)

            VStack(spacing: 20 * size / 255) {
                Circle()
                    .fill(Color(red: 0.961, green: 0.62, blue: 0.043).opacity(0.95))
                    .frame(width: 72 * size / 255, height: 72 * size / 255)

                Text("PVT")
                    .font(.system(size: 9 * size / 255, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color(red: 0.961, green: 0.62, blue: 0.043))
            }
            .offset(x: 82 * size / 255, y: 38 * size / 255)
        }
        .frame(width: size, height: size)
    }

    private func roundedBar(width: CGFloat, height: CGFloat, color: Color) -> some View {
        RoundedRectangle(cornerRadius: 6 * width / 14, style: .continuous)
            .fill(color)
            .frame(width: width, height: height)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(.white.opacity(0.2))
                .frame(width: 8, height: 8)
            Circle()
                .fill(Color(red: 0.486, green: 0.361, blue: 1))
                .frame(width: 8, height: 8)
            Circle()
                .fill(.white.opacity(0.2))
                .frame(width: 8, height: 8)
        }
        .frame(maxWidth: .infinity, minHeight: 8, maxHeight: 8)
    }
}
