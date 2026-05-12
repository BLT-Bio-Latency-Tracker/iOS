import SwiftUI

struct OnboardingView: View {
    var onFinish: () -> Void = {}

    @State private var currentPage = 0
    @State private var transitionDirection = 1
    @State private var isStartButtonHighlighted = false
    @State private var startButtonHighlightGeneration = 0

    private let designWidth: CGFloat = 375
    private let designHeight: CGFloat = 812
    private let pageCount = 3

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / designWidth, proxy.size.height / designHeight)
            let horizontalInset = max(24, (proxy.size.width - 327 * scale) / 2)

            ZStack {
                Color(red: 0.039, green: 0.055, blue: 0.153)
                    .ignoresSafeArea()

                ZStack {
                    pageView
                        .id(currentPage)
                        .transition(pageTransition)
                }
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    header(scale: scale)
                        .padding(.top, 48 * scale)
                        .padding(.horizontal, horizontalInset)

                    Spacer(minLength: 0)

                    pageIndicator
                        .padding(.bottom, 20 * scale)

                    Button(action: primaryButtonTapped) {
                        Text(primaryButtonTitle)
                            .font(.system(size: 16 * scale, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52 * scale)
                            .background(primaryButtonBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 14 * scale, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(startButtonScale)
                    .offset(y: startButtonOffset(scale: scale))
                    .padding(.horizontal, horizontalInset)
                    .padding(.bottom, max(32, 32 * scale))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .simultaneousGesture(pageSwipeGesture)
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.40), value: currentPage)
        .onAppear(perform: updateStartButtonHighlight)
        .onChange(of: currentPage) { _ in
            updateStartButtonHighlight()
        }
    }

    private func moveToPage(_ page: Int) {
        let nextPage = min(max(page, 0), pageCount - 1)
        guard nextPage != currentPage else { return }

        transitionDirection = nextPage > currentPage ? 1 : -1
        currentPage = nextPage
    }

    private func header(scale: CGFloat) -> some View {
        HStack {
            Text("\(currentPage + 1) / 3")
                .font(.system(size: 12 * scale, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .contentTransition(.numericText())

            Spacer()

            Button(action: onFinish) {
                Text("건너뛰기")
                    .font(.system(size: 13 * scale, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color(red: 0.486, green: 0.361, blue: 1) : .white.opacity(0.2))
                    .frame(width: 8, height: 8)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 8, maxHeight: 8)
    }

    private var primaryButtonTitle: String {
        currentPage == 2 ? "시작하기" : "다음"
    }

    private var startButtonScale: CGFloat {
        currentPage == pageCount - 1 && isStartButtonHighlighted ? 1.045 : 1
    }

    private func startButtonOffset(scale: CGFloat) -> CGFloat {
        currentPage == pageCount - 1 && isStartButtonHighlighted ? -5 * scale : 0
    }

    private var primaryButtonBackground: some ShapeStyle {
        if currentPage == 2 {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.49, green: 0.36, blue: 1),
                        Color(red: 0.13, green: 0.83, blue: 0.93)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }

        return AnyShapeStyle(Color(red: 0.486, green: 0.361, blue: 1))
    }

    private func primaryButtonTapped() {
        if currentPage < pageCount - 1 {
            moveToPage(currentPage + 1)
        } else {
            onFinish()
        }
    }

    private func updateStartButtonHighlight() {
        startButtonHighlightGeneration += 1
        let generation = startButtonHighlightGeneration

        isStartButtonHighlighted = false

        guard currentPage == pageCount - 1 else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard generation == startButtonHighlightGeneration,
                  currentPage == pageCount - 1 else {
                return
            }

            withAnimation(.interpolatingSpring(stiffness: 210, damping: 6).repeatForever(autoreverses: true)) {
                isStartButtonHighlighted = true
            }
        }
    }

    @ViewBuilder
    private var pageView: some View {
        switch currentPage {
        case 0:
            OnboardingFirstPageView()
        case 1:
            OnboardingSecondPageView()
        default:
            OnboardingThirdPageView()
        }
    }

    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: 4)),
            removal: .opacity.combined(with: .offset(y: -4))
        )
    }

    private var pageSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let horizontalAmount = value.translation.width
                let verticalAmount = value.translation.height

                guard abs(horizontalAmount) > abs(verticalAmount),
                      abs(horizontalAmount) > 48 else {
                    return
                }

                if horizontalAmount < 0 {
                    moveToPage(currentPage + 1)
                } else {
                    moveToPage(currentPage - 1)
                }
            }
    }
}
