import SwiftUI

struct OnboardingFirstPageView: View {
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

                    brainSignalGraphic(size: 255 * scale)
                        .padding(.top, 51 * scale)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("당신의 뇌는 지금\n몇 %인가요?")
                            .font(.system(size: 26 * scale, weight: .heavy))
                            .foregroundStyle(.white)
                            .lineSpacing(6 * scale)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("카페인과 의지력으로 버티는 일상,\n그 이유를 데이터로 알려드려요")
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
            Text("1 / 3")
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

    private func brainSignalGraphic(size: CGFloat) -> some View {
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

            Circle()
                .fill(Color(red: 0.392, green: 0.306, blue: 0.792))
                .frame(width: size * 0.3, height: size * 0.3)
                .offset(x: -size * 0.02, y: -size * 0.02)

            Circle()
                .fill(Color(red: 0.176, green: 0.67, blue: 0.816))
                .frame(width: size * 0.17, height: size * 0.17)
                .offset(x: size * 0.17, y: size * 0.07)
        }
        .frame(width: size, height: size)
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(red: 0.486, green: 0.361, blue: 1))
                .frame(width: 8, height: 8)
            Circle()
                .fill(.white.opacity(0.2))
                .frame(width: 8, height: 8)
            Circle()
                .fill(.white.opacity(0.2))
                .frame(width: 8, height: 8)
        }
        .frame(maxWidth: .infinity, minHeight: 8, maxHeight: 8)
    }
}
