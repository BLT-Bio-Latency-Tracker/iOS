import SwiftUI

struct LoginView: View {
    var onAppleButtonTapped: () -> Void = {}

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
                    logo(scale: scale)
                        .padding(.top, 132 * scale)

                    Text("BLT")
                        .font(.system(size: 16 * scale, weight: .heavy))
                        .tracking(1)
                        .foregroundStyle(.white)
                        .frame(width: 70 * scale, height: 19 * scale)
                        .padding(.top, 8 * scale)

                    Text("당신의 뇌 컨디션을 측정하고\n매일 최적의 시간을 찾으세요")
                        .font(.system(size: 22 * scale, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5 * scale)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, horizontalInset)
                        .padding(.top, 65 * scale)

                    brainROISample(scale: scale)
                        .padding(.top, 50 * scale)

                    Spacer(minLength: 0)

                    appleLoginButton(scale: scale)
                        .padding(.horizontal, horizontalInset)
                        .padding(.bottom, 28 * scale)

                    Text("계속하면 BLT의 서비스 약관과\n개인정보 처리방침에 동의하게 됩니다")
                        .font(.system(size: 10 * scale, weight: .regular))
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4 * scale)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, horizontalInset)
                        .padding(.bottom, max(100 * scale, 64))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .preferredColorScheme(.dark)
    }

    private func logo(scale: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.486, green: 0.361, blue: 1))
                .frame(width: 24 * scale, height: 24 * scale)
                .offset(x: -6 * scale, y: -3 * scale)

            Circle()
                .fill(Color(red: 0.133, green: 0.827, blue: 0.933).opacity(0.85))
                .frame(width: 18 * scale, height: 18 * scale)
                .offset(x: 9 * scale, y: 6 * scale)
        }
        .frame(width: 48 * scale, height: 24 * scale)
    }

    private func brainROISample(scale: CGFloat) -> some View {
        VStack(spacing: 24 * scale) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.486, green: 0.361, blue: 1).opacity(0.3))
                    .frame(width: 96 * scale, height: 96 * scale)

                Circle()
                    .fill(Color(red: 0.133, green: 0.827, blue: 0.933).opacity(0.5))
                    .frame(width: 56 * scale, height: 56 * scale)
            }

            Text("Brain ROI\nSample")
                .font(.system(size: 10 * scale, weight: .medium))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .lineSpacing(2 * scale)
                .frame(width: 96 * scale)
        }
    }

    private func appleLoginButton(scale: CGFloat) -> some View {
        Button(action: onAppleButtonTapped) {
            HStack(spacing: 14 * scale) {
                Image(systemName: "apple.logo")
                    .font(.system(size: 22 * scale, weight: .medium))
                    .foregroundStyle(Color(red: 0.039, green: 0.055, blue: 0.153))

                Text("Apple로 계속하기")
                    .font(.system(size: 16 * scale, weight: .semibold))
                    .foregroundStyle(Color(red: 0.039, green: 0.055, blue: 0.153))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52 * scale)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Apple로 계속하기")
        .frame(height: 52 * scale)
    }
}
