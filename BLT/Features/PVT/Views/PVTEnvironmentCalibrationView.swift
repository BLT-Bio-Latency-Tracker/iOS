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
            calibrator.start()
        }
        .onDisappear {
            if case .calibration = step {
                calibrator.restoreBrightness()
            }
        }
        .onChange(of: calibrator.isFinished) { _, isFinished in
            guard isFinished else { return }
            step = .measurement
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
        ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    func start() {
        guard timer == nil, displayLink == nil else { return }

        let screen = Self.activeScreen
        originalBrightness = screen.brightness
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
}
