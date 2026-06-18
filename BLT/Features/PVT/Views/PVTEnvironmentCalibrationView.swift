import Combine
import SwiftUI
import UIKit

struct PVTEnvironmentCalibrationView: View {
    private enum Step {
        case calibration
        case measurement
        case calculation(PVTSummary)
        case complete(PVTSummary)
    }

    let onClose: () -> Void
    let onComplete: (PVTSummary) -> Void
    let onAbort: () -> Void

    @StateObject private var calibrator = PVTEnvironmentCalibrator()
    @State private var step: Step = .calibration
    @State private var qualityWarning: PVTCalibrationQualityWarning?

    private let designWidth: CGFloat = 390

    var body: some View {
        ZStack {
            switch step {
            case .calibration:
                calibrationContent

            case .measurement:
                PVTMeasurementContainerView(
                    environmentCalibration: calibrator.result,
                    onComplete: { summary in
                        calibrator.restoreBrightness()
                        step = .calculation(summary)
                    },
                    onAbort: {
                        calibrator.restoreBrightness()
                        onAbort()
                    }
                )
                .ignoresSafeArea()

            case .calculation(let summary):
                PVTCalculationSplashView {
                    step = .complete(summary)
                }
                .ignoresSafeArea()

            case .complete(let summary):
                PVTCalculationCompleteView(summary: summary) {
                    onComplete(summary)
                }
                .ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            startCalibration()
        }
        .onDisappear {
            if case .calibration = step {
                calibrator.restoreBrightness()
            }
        }
        .onChange(of: calibrator.isFinished) { _, isFinished in
            guard isFinished else { return }
            guard let result = calibrator.result else {
                step = .measurement
                return
            }

            if let warning = PVTCalibrationQualityWarning(result: result) {
                qualityWarning = warning
            } else {
                step = .measurement
            }
        }
        .sheet(item: $qualityWarning) { warning in
            GeometryReader { proxy in
                let scale = min(proxy.size.width / designWidth, 1.08)

                calibrationQualityWarningSheet(warning: warning, scale: scale)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            }
            .presentationDetents([.height(390)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(Color(red: 0.078, green: 0.098, blue: 0.216))
            .interactiveDismissDisabled()
            .preferredColorScheme(.dark)
        }
    }

    private var calibrationContent: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / designWidth
            let topPadding = max(36 * scale, 60 * scale - proxy.safeAreaInsets.top)

            ZStack {
                Color.pvtCalibrationBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    header(scale: scale)
                        .padding(.horizontal, 24 * scale)
                        .padding(.top, topPadding)

                    Spacer(minLength: 0)

                    VStack(spacing: 0) {
                        calibrationGraphic(scale: scale)

                        Text("Calibrating...")
                            .font(.system(size: 22 * scale, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.top, 50 * scale)

                        Text("화면 밝기와 응답 지연을 확인하고 있어요")
                            .font(.system(size: 13 * scale, weight: .regular))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .padding(.top, 9 * scale)

                        progressBar(scale: scale)
                            .padding(.top, 48 * scale)

                        Text(String(format: "%d%%", Int((calibrator.progress * 100).rounded())))
                            .font(.system(size: 11 * scale, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .padding(.top, 14 * scale)
                    }

                    Spacer(minLength: 0)

                    Text("잠시만 기다려주세요...")
                        .font(.system(size: 12 * scale, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(.bottom, max(92 * scale, 106 * scale - proxy.safeAreaInsets.bottom))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private func header(scale: CGFloat) -> some View {
        ZStack {
            Text("환경 보정")
                .font(.system(size: 14 * scale, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)

            HStack {
                Button {
                    calibrator.restoreBrightness()
                    onClose()
                } label: {
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

    private func calibrationGraphic(scale: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.pvtCalibrationCyan.opacity(0.15))
                .frame(width: 200 * scale, height: 200 * scale)
                .blur(radius: 32 * scale)

            Circle()
                .fill(Color.pvtCalibrationCyan.opacity(0.5))
                .frame(width: 80 * scale, height: 80 * scale)

            Circle()
                .fill(Color.pvtCalibrationCyan)
                .frame(width: 40 * scale, height: 40 * scale)
        }
        .accessibilityHidden(true)
    }

    private func progressBar(scale: CGFloat) -> some View {
        GeometryReader { proxy in
            let fillWidth = max(6 * scale, proxy.size.width * calibrator.progress)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.1))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Color.pvtCalibrationViolet, Color.pvtCalibrationCyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: fillWidth)
            }
        }
        .frame(width: 270 * scale, height: 6 * scale)
    }

    private func calibrationQualityWarningSheet(
        warning: PVTCalibrationQualityWarning,
        scale: CGFloat
    ) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(Color.pvtCalibrationWarning.opacity(0.15))
                    .frame(width: 72 * scale, height: 72 * scale)

                Text(warning.icon)
                    .font(.system(size: 28 * scale, weight: .regular))
                    .frame(width: 36 * scale, height: 36 * scale)
            }
            .padding(.top, 34 * scale)

            Text(warning.title)
                .font(.system(size: 19 * scale, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 16 * scale)

            Text(warning.message)
                .font(.system(size: 14 * scale, weight: .regular))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineSpacing(4 * scale)
                .frame(maxWidth: .infinity)
                .padding(.top, 10 * scale)
                .padding(.horizontal, 24 * scale)

            VStack(alignment: .leading, spacing: 0) {
                Text(warning.guideTitle)
                    .font(.system(size: 12 * scale, weight: .regular))
                    .foregroundStyle(Color.pvtCalibrationWarning.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.top, 12 * scale)

                Text(warning.guideDescription)
                    .font(.system(size: 12 * scale, weight: .regular))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .padding(.top, 9 * scale)
            }
            .padding(.horizontal, 16 * scale)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 64 * scale, alignment: .top)
            .background(Color.pvtCalibrationWarning.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12 * scale, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12 * scale, style: .continuous)
                    .stroke(Color.pvtCalibrationWarning.opacity(0.2), lineWidth: 1)
            }
            .padding(.horizontal, 24 * scale)
            .padding(.top, 18 * scale)

            Button {
                continueMeasurementDespiteWarning()
            } label: {
                Text("계속하기")
                    .font(.system(size: 15 * scale, weight: .regular))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56 * scale)
                    .background(
                        LinearGradient(
                            colors: [Color.pvtCalibrationViolet, Color.pvtCalibrationCyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24 * scale)
            .padding(.top, 36 * scale)
        }
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.078, green: 0.098, blue: 0.216))
    }

    private func startCalibration() {
        calibrator.start()
    }

    private func continueMeasurementDespiteWarning() {
        qualityWarning = nil
        step = .measurement
    }
}

@MainActor
private final class PVTEnvironmentCalibrator: NSObject, ObservableObject {
    @Published private(set) var progress: CGFloat = 0
    @Published private(set) var isFinished = false
    @Published private(set) var result: PVTEnvironmentCalibrationResult?

    private var originalBrightness: CGFloat?
    private var startTime: CFTimeInterval = 0
    private var previousTimerFire: CFTimeInterval = 0
    private var maxTimerDelay: CFTimeInterval = 0
    private var unstableFrameCount = 0
    private var timer: Timer?
    private var displayLink: CADisplayLink?
    private var lastDisplayTimestamp: CFTimeInterval?

    private let duration: CFTimeInterval = 1.8

    var isLowPowerModeEnabled: Bool {
        return ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    func start() {
        guard timer == nil, displayLink == nil else { return }

        let screen = Self.activeScreen
        if originalBrightness == nil {
            originalBrightness = screen.brightness
        }
        screen.brightness = 1

        let now = CACurrentMediaTime()
        startTime = now
        previousTimerFire = now

        let timer = Timer(
            timeInterval: 0.05,
            target: self,
            selector: #selector(timerDidFire(_:)),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        let displayLink = CADisplayLink(target: self, selector: #selector(displayLinkDidUpdate(_:)))
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }

    func restart() {
        stop()
        progress = 0
        isFinished = false
        result = nil
        previousTimerFire = 0
        maxTimerDelay = 0
        unstableFrameCount = 0
        lastDisplayTimestamp = nil
        start()
    }

    func restoreBrightness() {
        if let originalBrightness {
            Self.activeScreen.brightness = originalBrightness
        }
        stop()
    }

    @objc private func timerDidFire(_ timer: Timer) {
        tick()
    }

    private func tick() {
        let now = CACurrentMediaTime()
        let drift = max(0, now - previousTimerFire - 0.05)
        maxTimerDelay = max(maxTimerDelay, drift)
        previousTimerFire = now

        let elapsed = now - startTime
        progress = min(1, CGFloat(elapsed / duration))

        guard elapsed >= duration else { return }
        complete()
    }

    @objc private func displayLinkDidUpdate(_ displayLink: CADisplayLink) {
        defer { lastDisplayTimestamp = displayLink.timestamp }

        guard let lastDisplayTimestamp else { return }
        let interval = displayLink.timestamp - lastDisplayTimestamp
        if interval > displayLink.duration * 1.75 {
            unstableFrameCount += 1
        }
    }

    private func complete() {
        progress = 1
        result = PVTEnvironmentCalibrationResult(
            maxTimerDriftMilliseconds: Int((maxTimerDelay * 1000).rounded()),
            unstableFrameCount: unstableFrameCount,
            isLowPowerModeEnabled: isLowPowerModeEnabled
        )
        isFinished = true
        stop()
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        displayLink?.invalidate()
        displayLink = nil
    }

    private static var activeScreen: UIScreen {
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        return windowScene?.screen ?? UIScreen()
    }
}

private extension Color {
    static let pvtCalibrationBackground = Color(red: 0.039, green: 0.055, blue: 0.153)
    static let pvtCalibrationViolet = Color(red: 0.486, green: 0.361, blue: 1)
    static let pvtCalibrationCyan = Color(red: 0.133, green: 0.831, blue: 0.929)
    static let pvtCalibrationWarning = Color(red: 1, green: 0.82, blue: 0.2)
}

private struct PVTCalibrationQualityWarning: Equatable, Identifiable {
    let id: Kind
    let icon: String
    let title: String
    let message: String
    let guideTitle: String
    let guideDescription: String

    private init(
        id: Kind,
        icon: String,
        title: String,
        message: String,
        guideTitle: String,
        guideDescription: String
    ) {
        self.id = id
        self.icon = icon
        self.title = title
        self.message = message
        self.guideTitle = guideTitle
        self.guideDescription = guideDescription
    }

    static let lowPowerMode = PVTCalibrationQualityWarning(
        id: .lowPowerMode,
        icon: "⚡",
        title: "응답 지연이 감지됐어요",
        message: "저전력 모드가 켜져 있으면 반응속도\n측정 정확도가 낮아질 수 있어요.",
        guideTitle: "📲  설정 > 배터리 > 저전력 모드 끄기",
        guideDescription: "해제 후 재시작하면 더 정확한 캘리브레이션이 가능해요"
    )

    init?(result: PVTEnvironmentCalibrationResult) {
        if result.isLowPowerModeEnabled {
            self = .lowPowerMode
            return
        }

        if result.maxTimerDriftMilliseconds >= 80 {
            self.init(
                id: .timerDrift,
                icon: "⏱️",
                title: "메인 스레드 지연이 감지됐어요",
                message: "앱 전환이나 백그라운드 작업이 많으면\n반응속도 측정이 밀릴 수 있어요.",
                guideTitle: "📲  다른 앱을 정리하고 Bryki만 실행해보세요",
                guideDescription: "잠시 후 재시작하면 더 안정적인 측정이 가능해요"
            )
            return
        }

        if result.unstableFrameCount >= 3 {
            self.init(
                id: .unstableFrame,
                icon: "⚠️",
                title: "화면 갱신이 불안정해요",
                message: "프레임 드랍이 반복되면 자극 표시 시점이\n불안정해질 수 있어요.",
                guideTitle: "📲  화면 녹화·저전력·무거운 앱을 종료해보세요",
                guideDescription: "환경을 정리한 뒤 재시작하면 정확도가 올라가요"
            )
            return
        }

        return nil
    }

    enum Kind: Hashable {
        case lowPowerMode
        case timerDrift
        case unstableFrame
    }
}
