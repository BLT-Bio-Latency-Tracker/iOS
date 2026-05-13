import SwiftUI
import UIKit

struct StartReadyView: View {
    var onBack: () -> Void = {}
    var onStart: () -> Void = {}

    @State private var isSymbolVisible = false
    @State private var isButtonPressed = false

    private let designWidth: CGFloat = 375
    private let designHeight: CGFloat = 812

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / designWidth, proxy.size.height / designHeight)
            let contentWidth = min(proxy.size.width - 24, 351 * scale)
            let horizontalInset = max(12, (proxy.size.width - contentWidth) / 2)

            ZStack {
                Color(red: 0.039, green: 0.055, blue: 0.153)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header(scale: scale)
                        .padding(.top, 56 * scale)
                        .padding(.horizontal, horizontalInset)

                    Spacer()
                        .frame(height: 36 * scale)

                    readySymbol(scale: scale)

                    titleSection(scale: scale)
                        .padding(.top, 46 * scale)
                        .padding(.horizontal, horizontalInset)

                    statusCard(scale: scale)
                        .padding(.top, 42 * scale)
                        .padding(.horizontal, horizontalInset)

                    Spacer(minLength: 0)

                    startButton(scale: scale)
                        .padding(.horizontal, horizontalInset)
                        .padding(.bottom, max(55, 55 * scale))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            UIImpactFeedbackGenerator(style: .light).prepare()

            withAnimation(.spring(response: 0.9, dampingFraction: 0.82).delay(0.42)) {
                isSymbolVisible = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    private func header(scale: CGFloat) -> some View {
        HStack {
            Button(action: onBack) {
                Text("←")
                    .font(.system(size: 16 * scale, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 32 * scale, height: 32 * scale)
                    .background(.clear)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.15), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private func readySymbol(scale: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.486, green: 0.361, blue: 1).opacity(0.16))
                .frame(width: 172 * scale, height: 172 * scale)
                .scaleEffect(isSymbolVisible ? 1 : 0.82)

            Circle()
                .fill(Color(red: 0.133, green: 0.827, blue: 0.933).opacity(0.16))
                .frame(width: 118 * scale, height: 118 * scale)
                .offset(x: 18 * scale, y: 10 * scale)
                .scaleEffect(isSymbolVisible ? 1 : 0.76)

            Circle()
                .fill(Color(red: 0.486, green: 0.361, blue: 1))
                .frame(width: 78 * scale, height: 78 * scale)
                .overlay {
                    Text("✓")
                        .font(.system(size: 36 * scale, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(y: -1 * scale)
                }
                .scaleEffect(isSymbolVisible ? 1 : 0.62)
        }
        .frame(width: 172 * scale, height: 172 * scale)
        .opacity(isSymbolVisible ? 1 : 0)
    }

    private func titleSection(scale: CGFloat) -> some View {
        VStack(spacing: 18 * scale) {
            Text("준비가 끝났어요")
                .font(.system(size: 30 * scale, weight: .heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            Text("이제 수면과 반응속도를 바탕으로\n오늘의 Brain ROI를 확인해보세요")
                .font(.system(size: 15 * scale, weight: .regular))
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
                .lineSpacing(5 * scale)
        }
        .frame(maxWidth: .infinity)
    }

    private func statusCard(scale: CGFloat) -> some View {
        VStack(spacing: 0) {
            statusRow(title: "초기 설정", value: "완료", scale: scale)

            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(height: 1)
                .padding(.vertical, 14 * scale)

            statusRow(title: "다음 단계", value: "Brain ROI 측정", scale: scale)
        }
        .padding(.horizontal, 18 * scale)
        .frame(maxWidth: .infinity)
        .frame(height: 112 * scale)
        .background(Color(red: 0.078, green: 0.098, blue: 0.216))
        .clipShape(RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }

    private func statusRow(title: String, value: String, scale: CGFloat) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14 * scale, weight: .medium))
                .foregroundStyle(.white.opacity(0.52))

            Spacer()

            Text(value)
                .font(.system(size: 14 * scale, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private func startButton(scale: CGFloat) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.85)
            onStart()
        } label: {
            Text("BLT 시작하기")
                .font(.system(size: 17 * scale, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56 * scale)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.49, green: 0.36, blue: 1),
                            Color(red: 0.13, green: 0.83, blue: 0.93)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
                .scaleEffect(isButtonPressed ? 0.98 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isButtonPressed = true
                }
                .onEnded { _ in
                    isButtonPressed = false
                }
        )
    }
}
