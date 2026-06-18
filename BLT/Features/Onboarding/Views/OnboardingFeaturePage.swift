import SwiftUI

struct OnboardingFeaturePage: View {
    let icon: String
    let accentColor: Color
    let panelColor: Color
    let title: String
    let description: String

    private let designWidth: CGFloat = 390
    private let designHeight: CGFloat = 844

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / designWidth, proxy.size.height / designHeight)
            let horizontalInset = max(28, (proxy.size.width - 334 * scale) / 2)

            VStack(alignment: .leading, spacing: 0) {
                visualPanel(scale: scale)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 96 * scale)

                Text(title)
                    .font(.system(size: 32 * scale, weight: .heavy))
                    .foregroundStyle(.white)
                    .lineSpacing(6 * scale)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 36 * scale)
                    .padding(.horizontal, horizontalInset)

                Text(description)
                    .font(.system(size: 14 * scale, weight: .regular))
                    .foregroundStyle(.white.opacity(0.48))
                    .lineSpacing(6 * scale)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 22 * scale)
                    .padding(.horizontal, horizontalInset)

                Spacer(minLength: 0)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func visualPanel(scale: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20 * scale, style: .continuous)
                .fill(panelColor)
                .frame(width: 334 * scale, height: 340 * scale)

            concentricCircle(diameter: 250 * scale, opacity: 0.16)
            concentricCircle(diameter: 188 * scale, opacity: 0.22)
            concentricCircle(diameter: 126 * scale, opacity: 0.28)
            concentricCircle(diameter: 66 * scale, opacity: 0.92)

            Text(icon)
                .font(.system(size: 31 * scale))
                .frame(width: 66 * scale, height: 66 * scale)
        }
        .frame(width: 334 * scale, height: 340 * scale)
    }

    private func concentricCircle(diameter: CGFloat, opacity: Double) -> some View {
        Circle()
            .fill(accentColor.opacity(opacity))
            .frame(width: diameter, height: diameter)
    }
}
