import SwiftUI

struct OnboardingFirstPageView: View {
    private let designWidth: CGFloat = 375
    private let designHeight: CGFloat = 812

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / designWidth, proxy.size.height / designHeight)
            let horizontalInset = max(24, (proxy.size.width - 327 * scale) / 2)

            ZStack {
                VStack(spacing: 0) {
                    brainSignalGraphic(size: 255 * scale)
                        .padding(.top, 130 * scale)

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
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
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

}
