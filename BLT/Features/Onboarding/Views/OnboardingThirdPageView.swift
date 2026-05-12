import SwiftUI

struct OnboardingThirdPageView: View {
    private let designWidth: CGFloat = 375
    private let designHeight: CGFloat = 812

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / designWidth, proxy.size.height / designHeight)
            let horizontalInset = max(24, (proxy.size.width - 327 * scale) / 2)

            ZStack {
                VStack(spacing: 0) {
                    recommendationGraphic(size: 255 * scale)
                        .padding(.top, 130 * scale)

                    VStack(alignment: .leading, spacing: 0) {
                        Text("오늘 가장 어려운 일을\n언제 할지 알려드려요")
                            .font(.system(size: 26 * scale, weight: .heavy))
                            .foregroundStyle(.white)
                            .lineSpacing(6 * scale)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Brain ROI 점수와 시간대별 추천으로\n매일 더 나은 컨디션을")
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

    private func recommendationGraphic(size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.486, green: 0.361, blue: 1).opacity(0.28),
                            Color(red: 0.091, green: 0.257, blue: 0.475).opacity(0.16),
                            .clear
                        ],
                        center: .center,
                        startRadius: 18,
                        endRadius: size * 0.6
                    )
                )
                .blur(radius: 12)
                .frame(width: size, height: size)

            VStack(alignment: .leading, spacing: 11 * size / 255) {
                timeBlock(
                    title: "DEEP WORK · 09–12",
                    textColor: .white,
                    color: Color(red: 0.486, green: 0.361, blue: 1),
                    width: 215 * size / 255,
                    height: 14 * size / 255,
                    scale: size / 255
                )
                timeBlock(
                    title: "COLLAB · 13–16",
                    textColor: .white,
                    color: Color(red: 0.063, green: 0.725, blue: 0.506).opacity(0.85),
                    width: 215 * size / 255,
                    height: 14 * size / 255,
                    scale: size / 255
                )
                timeBlock(
                    title: "CAUTION · 16–18",
                    textColor: Color(red: 0.039, green: 0.055, blue: 0.153),
                    color: Color(red: 0.961, green: 0.62, blue: 0.043).opacity(0.85),
                    width: 215 * size / 255,
                    height: 14 * size / 255,
                    scale: size / 255
                )
                timeBlock(
                    title: "RECOVERY · 19–",
                    textColor: Color(red: 0.039, green: 0.055, blue: 0.153),
                    color: Color(red: 0.133, green: 0.827, blue: 0.933).opacity(0.85),
                    width: 215 * size / 255,
                    height: 14 * size / 255,
                    scale: size / 255
                )
            }
            .offset(y: -46 * size / 255)

            VStack(spacing: 0) {
                Circle()
                    .fill(.white)
                    .frame(width: 18 * size / 255, height: 18 * size / 255)

                Rectangle()
                    .fill(.white)
                    .frame(width: 4 * size / 255, height: 22 * size / 255)

                Text("지금 09:43")
                    .font(.system(size: 10 * size / 255, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 80 * size / 255, height: 12 * size / 255)
                    .padding(.top, 10 * size / 255)
            }
            .offset(y: 63 * size / 255)
        }
        .frame(width: size, height: size)
    }

    private func timeBlock(
        title: String,
        textColor: Color,
        color: Color,
        width: CGFloat,
        height: CGFloat,
        scale: CGFloat
    ) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(color)
                .frame(width: width, height: height)

            Text(title)
                .font(.system(size: 9 * scale, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.leading, 8 * scale)
        }
    }

}
