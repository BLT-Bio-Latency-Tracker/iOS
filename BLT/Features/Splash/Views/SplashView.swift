import Combine
import SwiftUI

struct SplashView: View {
    var onFinish: () -> Void

    @State private var isLogoVisible = false
    @State private var activeDotIndex = 0

    private let designWidth: CGFloat = 375
    private let designHeight: CGFloat = 812
    private let dotTimer = Timer.publish(every: 0.28, on: .main, in: .common).autoconnect()

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / designWidth, proxy.size.height / designHeight)
            let centerX = proxy.size.width / 2
            let topInset = max(0, (proxy.size.height - designHeight * scale) / 2)

            ZStack {
                Color(red: 0.039, green: 0.055, blue: 0.153)
                    .ignoresSafeArea()

                ZStack {
                    logoMark(scale: scale)
                        .position(x: centerX, y: topInset + 372 * scale)

                    Text("BLT")
                        .font(.system(size: 36 * scale, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 80 * scale, height: 44 * scale)
                        .position(x: centerX, y: topInset + 418 * scale)

                    Text("Brain Level Tracker")
                        .font(.system(size: 11 * scale, weight: .medium))
                        .tracking(2 * scale)
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 175 * scale, height: 13 * scale)
                        .position(x: centerX, y: topInset + 448.5 * scale)

                    loadingDots(scale: scale)
                        .position(x: centerX, y: topInset + 543 * scale)
                }
                .opacity(isLogoVisible ? 1 : 0)
                .scaleEffect(isLogoVisible ? 1 : 0.96)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .preferredColorScheme(.dark)
        .onReceive(dotTimer) { _ in
            activeDotIndex = (activeDotIndex + 1) % 3
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) {
                isLogoVisible = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                onFinish()
            }
        }
    }

    private func logoMark(scale: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.486, green: 0.361, blue: 1))
                .frame(width: 24 * scale, height: 24 * scale)
                .offset(x: -8 * scale, y: -6 * scale)

            Circle()
                .fill(Color(red: 0.133, green: 0.827, blue: 0.933).opacity(0.85))
                .frame(width: 18 * scale, height: 18 * scale)
                .offset(x: 9 * scale, y: 6 * scale)
        }
        .frame(width: 34 * scale, height: 36 * scale)
    }

    private func loadingDots(scale: CGFloat) -> some View {
        HStack(spacing: 6 * scale) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color(red: 0.486, green: 0.361, blue: 1))
                    .frame(width: 6 * scale, height: 6 * scale)
                    .opacity(dotOpacity(for: index))
                    .scaleEffect(activeDotIndex == index ? 1.14 : 1)
                    .animation(.easeInOut(duration: 0.22), value: activeDotIndex)
            }
        }
    }

    private func dotOpacity(for index: Int) -> Double {
        switch (index - activeDotIndex + 3) % 3 {
        case 0:
            return 1
        case 1:
            return 0.6
        default:
            return 0.3
        }
    }
}
