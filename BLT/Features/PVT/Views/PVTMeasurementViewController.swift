import Combine
import UIKit

final class PVTMeasurementViewController: UIViewController {
    private enum OrbPresentation {
        case waiting
        case stimulus
        case resultText
        case hidden
    }

    private let viewModel: PVTTestViewModel
    private let onComplete: (PVTSummary) -> Void
    private var cancellables = Set<AnyCancellable>()
    private var displayLink: CADisplayLink?
    private var resultFeedbackWorkItem: DispatchWorkItem?
    private var currentOrbPresentation: OrbPresentation = .hidden

    private let statusPill = UIView()
    private let statusDot = CircleView()
    private let statusLabel = UILabel()
    private let progressLabel = UILabel()
    private let responseTitleLabel = UILabel()
    private let rippleView = RippleWaveView()
    private let orbHaloView = UIView()
    private let orbMiddleHaloView = UIView()
    private let orbView = UIView()
    private let elapsedLabel = UILabel()
    private let millisecondsLabel = UILabel()
    private let instructionLabel = UILabel()
    private let dividerView = UIView()
    private let bestTitleLabel = UILabel()
    private let bestValueLabel = UILabel()
    private let averageTitleLabel = UILabel()
    private let averageValueLabel = UILabel()
    private let lapseTitleLabel = UILabel()
    private let lapseValueLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let interruptButton = UIButton(type: .system)
    private let interruptDimView = UIView()
    private let interruptDialogView = UIView()
    private let interruptIconContainerView = UIView()
    private let interruptIconLabel = UILabel()
    private let interruptTitleLabel = UILabel()
    private let interruptMessageLabel = UILabel()
    private let interruptCancelButton = UIButton(type: .system)
    private let interruptAbortButton = UIButton(type: .system)

    private let onAbort: () -> Void

    init(
        viewModel: PVTTestViewModel,
        onComplete: @escaping (PVTSummary) -> Void,
        onAbort: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onComplete = onComplete
        self.onAbort = onAbort
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var prefersStatusBarHidden: Bool {
        false
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureHierarchy()
        configureConstraints()
        bindViewModel()
        viewModel.start()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyCircleMasks()
        if currentOrbPresentation == .waiting || currentOrbPresentation == .stimulus {
            let isStimulus = currentOrbPresentation == .stimulus
            applyOrbStyle(isStimulus: isStimulus)
            rippleView.setStyle(isStimulus ? .stimulus : .waiting)
            rippleView.startAnimating()
        } else {
            setOrbPresentation(currentOrbPresentation)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopDisplayLink()
        rippleView.stopAnimating()
        cancelResultFeedback()
        viewModel.stop()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard interruptDialogView.isHidden else {
            return
        }

        let touchTime = CACurrentMediaTime()
        super.touchesBegan(touches, with: event)
        viewModel.handleTap(at: touchTime)
    }

    private func configureView() {
        view.backgroundColor = PVTTheme.inkNavy

        statusPill.backgroundColor = UIColor.white.withAlphaComponent(0.09)
        statusPill.isUserInteractionEnabled = false

        statusDot.backgroundColor = PVTTheme.activeMint

        statusLabel.text = "측정 중"
        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 12, weight: .bold)

        progressLabel.textColor = UIColor.white.withAlphaComponent(0.68)
        progressLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .bold)
        progressLabel.textAlignment = .right

        responseTitleLabel.text = "RESPONSE TIME"
        responseTitleLabel.textColor = UIColor.white.withAlphaComponent(0.66)
        responseTitleLabel.font = .systemFont(ofSize: 13, weight: .bold)
        responseTitleLabel.textAlignment = .center
        responseTitleLabel.letterSpacing = 3.2

        rippleView.alpha = 0
        rippleView.clipsToBounds = false
        rippleView.isUserInteractionEnabled = false

        orbHaloView.backgroundColor = UIColor(red: 0.34, green: 0.29, blue: 0.24, alpha: 0.68)
        orbHaloView.alpha = 0
        orbHaloView.clipsToBounds = true
        orbHaloView.isUserInteractionEnabled = false

        orbMiddleHaloView.backgroundColor = UIColor(red: 0.62, green: 0.51, blue: 0.28, alpha: 0.62)
        orbMiddleHaloView.alpha = 0
        orbMiddleHaloView.clipsToBounds = true
        orbMiddleHaloView.isUserInteractionEnabled = false

        orbView.backgroundColor = PVTTheme.stimulus
        orbView.alpha = 0
        orbView.clipsToBounds = true
        orbView.isUserInteractionEnabled = false

        elapsedLabel.text = "0"
        elapsedLabel.textColor = UIColor.black.withAlphaComponent(0.9)
        elapsedLabel.font = .monospacedDigitSystemFont(ofSize: 52, weight: .black)
        elapsedLabel.textAlignment = .center
        elapsedLabel.adjustsFontSizeToFitWidth = true
        elapsedLabel.minimumScaleFactor = 0.5

        millisecondsLabel.text = "MS"
        millisecondsLabel.textColor = UIColor.black.withAlphaComponent(0.58)
        millisecondsLabel.font = .systemFont(ofSize: 13, weight: .black)
        millisecondsLabel.textAlignment = .center

        instructionLabel.text = "기다리세요"
        instructionLabel.textColor = UIColor.white.withAlphaComponent(0.54)
        instructionLabel.font = .systemFont(ofSize: 20, weight: .bold)
        instructionLabel.textAlignment = .center

        dividerView.backgroundColor = UIColor.white.withAlphaComponent(0.12)

        configureMetric(titleLabel: bestTitleLabel, valueLabel: bestValueLabel, title: "BEST")
        configureMetric(titleLabel: averageTitleLabel, valueLabel: averageValueLabel, title: "AVG")
        configureMetric(titleLabel: lapseTitleLabel, valueLabel: lapseValueLabel, title: "LAPSE")

        interruptButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        interruptButton.tintColor = UIColor.white.withAlphaComponent(0.72)
        interruptButton.contentHorizontalAlignment = .left
        interruptButton.addTarget(self, action: #selector(interruptTapped), for: .touchUpInside)

        closeButton.setTitle("완료", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 13, weight: .bold)
        closeButton.backgroundColor = PVTTheme.brandViolet
        closeButton.layer.cornerRadius = 20
        closeButton.alpha = 0
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        interruptDimView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        interruptDimView.alpha = 0

        interruptDialogView.backgroundColor = UIColor(red: 0.078, green: 0.098, blue: 0.216, alpha: 1)
        interruptDialogView.layer.cornerRadius = 22
        interruptDialogView.layer.borderWidth = 1
        interruptDialogView.layer.borderColor = UIColor.white.withAlphaComponent(0.1).cgColor

        interruptIconContainerView.backgroundColor = UIColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 0.18)
        interruptIconContainerView.clipsToBounds = true

        interruptIconLabel.text = "⚠️"
        interruptIconLabel.font = .systemFont(ofSize: 22)
        interruptIconLabel.textAlignment = .center

        interruptTitleLabel.text = "측정을 중단하시겠어요?"
        interruptTitleLabel.textColor = .white
        interruptTitleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        interruptTitleLabel.textAlignment = .center

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = 1.24
        paragraphStyle.alignment = .center
        interruptMessageLabel.attributedText = NSAttributedString(
            string: "지금까지 기록한 데이터는 저장되지 않아요.\n중단 후 처음부터 다시 측정해야 합니다.",
            attributes: [.paragraphStyle: paragraphStyle]
        )
        interruptMessageLabel.textColor = UIColor.white.withAlphaComponent(0.6)
        interruptMessageLabel.font = .systemFont(ofSize: 12, weight: .regular)
        interruptMessageLabel.numberOfLines = 0
        interruptMessageLabel.textAlignment = .center

        configureInterruptActionButton(
            interruptCancelButton,
            title: "취소",
            backgroundColor: UIColor(red: 0.16, green: 0.16, blue: 0.28, alpha: 1),
            titleColor: UIColor.white.withAlphaComponent(0.85),
            action: #selector(interruptCancelTapped)
        )
        configureInterruptActionButton(
            interruptAbortButton,
            title: "중단하기",
            backgroundColor: UIColor(red: 0.937, green: 0.267, blue: 0.267, alpha: 1),
            titleColor: .white,
            action: #selector(interruptAbortTapped)
        )
    }

    private func configureHierarchy() {
        [
            statusPill,
            progressLabel,
            responseTitleLabel,
            orbHaloView,
            rippleView,
            instructionLabel,
            dividerView,
            closeButton,
            interruptButton
        ].forEach {
            view.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        [statusDot, statusLabel].forEach {
            statusPill.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        [orbMiddleHaloView].forEach {
            orbHaloView.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        [orbView].forEach {
            orbMiddleHaloView.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        [elapsedLabel, millisecondsLabel].forEach {
            view.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        [bestTitleLabel, bestValueLabel, averageTitleLabel, averageValueLabel, lapseTitleLabel, lapseValueLabel].forEach {
            view.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        [interruptDimView, interruptDialogView].forEach {
            view.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        [
            interruptIconContainerView,
            interruptTitleLabel,
            interruptMessageLabel,
            interruptCancelButton,
            interruptAbortButton
        ].forEach {
            interruptDialogView.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        interruptIconContainerView.addSubview(interruptIconLabel)
        interruptIconLabel.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureConstraints() {
        NSLayoutConstraint.activate([
            statusPill.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 32),
            statusPill.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 42),
            statusPill.widthAnchor.constraint(equalToConstant: 70),
            statusPill.heightAnchor.constraint(equalToConstant: 28),

            statusDot.leadingAnchor.constraint(equalTo: statusPill.leadingAnchor, constant: 12),
            statusDot.centerYAnchor.constraint(equalTo: statusPill.centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 5),
            statusDot.heightAnchor.constraint(equalToConstant: 5),

            statusLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 7),
            statusLabel.centerYAnchor.constraint(equalTo: statusPill.centerYAnchor),

            progressLabel.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -32),
            progressLabel.centerYAnchor.constraint(equalTo: statusPill.centerYAnchor),

            responseTitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            responseTitleLabel.topAnchor.constraint(equalTo: statusPill.bottomAnchor, constant: 52),

            rippleView.centerXAnchor.constraint(equalTo: orbHaloView.centerXAnchor),
            rippleView.centerYAnchor.constraint(equalTo: orbHaloView.centerYAnchor),
            rippleView.widthAnchor.constraint(equalTo: orbHaloView.widthAnchor, multiplier: 1.22),
            rippleView.heightAnchor.constraint(equalTo: rippleView.widthAnchor),

            orbHaloView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            orbHaloView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -58),
            orbHaloView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.64),
            orbHaloView.heightAnchor.constraint(equalTo: orbHaloView.widthAnchor),

            orbMiddleHaloView.centerXAnchor.constraint(equalTo: orbHaloView.centerXAnchor),
            orbMiddleHaloView.centerYAnchor.constraint(equalTo: orbHaloView.centerYAnchor),
            orbMiddleHaloView.widthAnchor.constraint(equalTo: orbHaloView.widthAnchor, multiplier: 0.88),
            orbMiddleHaloView.heightAnchor.constraint(equalTo: orbMiddleHaloView.widthAnchor),

            orbView.centerXAnchor.constraint(equalTo: orbMiddleHaloView.centerXAnchor),
            orbView.centerYAnchor.constraint(equalTo: orbMiddleHaloView.centerYAnchor),
            orbView.widthAnchor.constraint(equalTo: orbMiddleHaloView.widthAnchor, multiplier: 0.82),
            orbView.heightAnchor.constraint(equalTo: orbView.widthAnchor),

            elapsedLabel.leadingAnchor.constraint(equalTo: orbView.leadingAnchor, constant: 20),
            elapsedLabel.trailingAnchor.constraint(equalTo: orbView.trailingAnchor, constant: -20),
            elapsedLabel.centerYAnchor.constraint(equalTo: orbView.centerYAnchor, constant: -8),

            millisecondsLabel.topAnchor.constraint(equalTo: elapsedLabel.bottomAnchor, constant: 6),
            millisecondsLabel.centerXAnchor.constraint(equalTo: orbView.centerXAnchor),

            instructionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            instructionLabel.topAnchor.constraint(equalTo: orbHaloView.bottomAnchor, constant: 56),
            instructionLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            instructionLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32),

            dividerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            dividerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            dividerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -110),
            dividerView.heightAnchor.constraint(equalToConstant: 1),

            bestTitleLabel.leadingAnchor.constraint(equalTo: dividerView.leadingAnchor),
            bestTitleLabel.topAnchor.constraint(equalTo: dividerView.bottomAnchor, constant: 26),
            bestValueLabel.leadingAnchor.constraint(equalTo: bestTitleLabel.leadingAnchor),
            bestValueLabel.topAnchor.constraint(equalTo: bestTitleLabel.bottomAnchor, constant: 8),

            averageTitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            averageTitleLabel.topAnchor.constraint(equalTo: bestTitleLabel.topAnchor),
            averageValueLabel.centerXAnchor.constraint(equalTo: averageTitleLabel.centerXAnchor),
            averageValueLabel.topAnchor.constraint(equalTo: bestValueLabel.topAnchor),

            lapseTitleLabel.trailingAnchor.constraint(equalTo: dividerView.trailingAnchor),
            lapseTitleLabel.topAnchor.constraint(equalTo: bestTitleLabel.topAnchor),
            lapseValueLabel.trailingAnchor.constraint(equalTo: lapseTitleLabel.trailingAnchor),
            lapseValueLabel.topAnchor.constraint(equalTo: bestValueLabel.topAnchor),

            closeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            closeButton.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 34),
            closeButton.widthAnchor.constraint(equalToConstant: 124),
            closeButton.heightAnchor.constraint(equalToConstant: 42),

            interruptButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            interruptButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: -12),
            interruptButton.widthAnchor.constraint(equalToConstant: 44),
            interruptButton.heightAnchor.constraint(equalToConstant: 44),

            interruptDimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            interruptDimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            interruptDimView.topAnchor.constraint(equalTo: view.topAnchor),
            interruptDimView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            interruptDialogView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            interruptDialogView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            interruptDialogView.widthAnchor.constraint(equalToConstant: 326),
            interruptDialogView.heightAnchor.constraint(equalToConstant: 280),

            interruptIconContainerView.centerXAnchor.constraint(equalTo: interruptDialogView.centerXAnchor),
            interruptIconContainerView.topAnchor.constraint(equalTo: interruptDialogView.topAnchor, constant: 30),
            interruptIconContainerView.widthAnchor.constraint(equalToConstant: 40),
            interruptIconContainerView.heightAnchor.constraint(equalToConstant: 40),

            interruptIconLabel.centerXAnchor.constraint(equalTo: interruptIconContainerView.centerXAnchor),
            interruptIconLabel.centerYAnchor.constraint(equalTo: interruptIconContainerView.centerYAnchor),
            interruptIconLabel.widthAnchor.constraint(equalTo: interruptIconContainerView.widthAnchor),
            interruptIconLabel.heightAnchor.constraint(equalToConstant: 27),

            interruptTitleLabel.leadingAnchor.constraint(equalTo: interruptDialogView.leadingAnchor),
            interruptTitleLabel.trailingAnchor.constraint(equalTo: interruptDialogView.trailingAnchor),
            interruptTitleLabel.topAnchor.constraint(equalTo: interruptIconContainerView.bottomAnchor, constant: 22),

            interruptMessageLabel.leadingAnchor.constraint(equalTo: interruptDialogView.leadingAnchor, constant: 20),
            interruptMessageLabel.trailingAnchor.constraint(equalTo: interruptDialogView.trailingAnchor, constant: -20),
            interruptMessageLabel.topAnchor.constraint(equalTo: interruptTitleLabel.bottomAnchor, constant: 10),

            interruptCancelButton.leadingAnchor.constraint(equalTo: interruptDialogView.leadingAnchor, constant: 20),
            interruptCancelButton.bottomAnchor.constraint(equalTo: interruptDialogView.bottomAnchor, constant: -32),
            interruptCancelButton.widthAnchor.constraint(equalToConstant: 132),
            interruptCancelButton.heightAnchor.constraint(equalToConstant: 48),

            interruptAbortButton.trailingAnchor.constraint(equalTo: interruptDialogView.trailingAnchor, constant: -20),
            interruptAbortButton.bottomAnchor.constraint(equalTo: interruptDialogView.bottomAnchor, constant: -32),
            interruptAbortButton.widthAnchor.constraint(equalToConstant: 132),
            interruptAbortButton.heightAnchor.constraint(equalToConstant: 48)
        ])

        interruptDimView.isHidden = true
        interruptDialogView.isHidden = true
    }

    private func bindViewModel() {
        viewModel.$phase
            .sink { [weak self] phase in
                self?.render(phase: phase)
            }
            .store(in: &cancellables)

        viewModel.$currentElapsedMilliseconds
            .sink { [weak self] milliseconds in
                self?.elapsedLabel.text = "\(milliseconds)"
            }
            .store(in: &cancellables)

        viewModel.$trials
            .sink { [weak self] trials in
                self?.updateMetrics(with: trials)
            }
            .store(in: &cancellables)
    }

    private func render(phase: PVTTestViewModel.Phase) {
        progressLabel.text = String(format: "%02d / %02d", viewModel.completedTrialCount + 1, viewModel.totalTrials)

        switch phase {
        case .waiting:
            statusLabel.text = "측정 중"
            statusDot.backgroundColor = PVTTheme.activeMint
            stopDisplayLink()
            if viewModel.isShowingFalseStart {
                cancelResultFeedback()
                setOrbPresentation(.waiting)
                instructionLabel.text = "너무 빨랐어요"
                instructionLabel.textColor = UIColor(red: 1, green: 0.55, blue: 0.32, alpha: 1)
                scheduleWaitingStateAfterFeedback()
            } else if viewModel.isShowingSlowLapse {
                cancelResultFeedback()
                setOrbPresentation(.resultText)
                instructionLabel.text = "너무 느렸어요"
                instructionLabel.textColor = UIColor(red: 1, green: 0.55, blue: 0.32, alpha: 1)
                scheduleWaitingStateAfterFeedback()
            } else if viewModel.completedTrialCount > 0 {
                setOrbPresentation(.resultText)
                instructionLabel.text = "대기하세요"
                instructionLabel.textColor = UIColor.white.withAlphaComponent(0.54)
                scheduleWaitingStateAfterFeedback()
            } else {
                cancelResultFeedback()
                setOrbPresentation(.waiting)
                instructionLabel.text = "대기하세요"
                instructionLabel.textColor = UIColor.white.withAlphaComponent(0.54)
            }
            closeButton.alpha = 0
            interruptButton.alpha = 1

        case .stimulus:
            statusLabel.text = "측정 중"
            statusDot.backgroundColor = PVTTheme.activeMint
            cancelResultFeedback()
            setOrbPresentation(.stimulus)
            instructionLabel.text = "지금 누르세요"
            instructionLabel.textColor = UIColor(red: 1, green: 0.84, blue: 0.22, alpha: 1)
            startDisplayLink()
            closeButton.alpha = 0
            interruptButton.alpha = 1

        case .completed:
            statusLabel.text = "측정완료"
            statusDot.backgroundColor = PVTTheme.brandViolet
            stopDisplayLink()
            cancelResultFeedback()
            setOrbPresentation(.resultText)
            progressLabel.text = String(format: "%02d / %02d", viewModel.totalTrials, viewModel.totalTrials)
            instructionLabel.text = "측정 완료"
            instructionLabel.textColor = .white
            closeButton.alpha = 1
            interruptButton.alpha = 0
        }
    }

    private func updateMetrics(with trials: [PVTTrial]) {
        let summary = PVTSummary(
            trials: trials,
            lapseThresholdMilliseconds: viewModel.lapseThresholdMilliseconds,
            excludesLapsesFromAverage: viewModel.excludesLapsesFromAverage
        )

        bestValueLabel.text = formattedMetric(summary.bestMilliseconds)
        averageValueLabel.text = formattedMetric(summary.averageMilliseconds)
        lapseValueLabel.text = "\(summary.lapseCount)"
    }

    private func formattedMetric(_ milliseconds: Int?) -> String {
        guard let milliseconds else {
            return "-- ms"
        }
        return "\(milliseconds) ms"
    }

    private func setOrbPresentation(_ presentation: OrbPresentation) {
        currentOrbPresentation = presentation

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        applyCircleMasks()
        rippleView.stopAnimating()

        switch presentation {
        case .waiting:
            applyOrbStyle(isStimulus: false)
            rippleView.setStyle(.waiting)
            setOrbLayersVisible(true)
            setElapsedTextVisible(false)

        case .stimulus:
            applyOrbStyle(isStimulus: true)
            rippleView.setStyle(.stimulus)
            setOrbLayersVisible(true)
            setElapsedTextVisible(true)
            elapsedLabel.textColor = UIColor.black.withAlphaComponent(0.9)
            millisecondsLabel.textColor = UIColor.black.withAlphaComponent(0.58)

        case .resultText:
            setOrbLayersVisible(false)
            setElapsedTextVisible(true)
            elapsedLabel.textColor = .white
            millisecondsLabel.textColor = UIColor.white.withAlphaComponent(0.64)

        case .hidden:
            setOrbLayersVisible(false)
            setElapsedTextVisible(false)
        }

        elapsedLabel.text = "\(viewModel.currentElapsedMilliseconds)"
        CATransaction.commit()

        if presentation == .waiting || presentation == .stimulus {
            startOrbRippleAnimation()
        }
    }

    private func applyCircleMasks() {
        statusPill.layer.cornerRadius = statusPill.bounds.height / 2
        interruptIconContainerView.layer.cornerRadius = interruptIconContainerView.bounds.height / 2
        [orbHaloView, orbMiddleHaloView, orbView].forEach { orbLayerView in
            orbLayerView.layoutIfNeeded()
            orbLayerView.layer.cornerRadius = min(orbLayerView.bounds.width, orbLayerView.bounds.height) / 2
            orbLayerView.layer.masksToBounds = true
        }
    }

    private func setOrbLayersVisible(_ isVisible: Bool) {
        rippleView.alpha = isVisible ? 1 : 0
        orbHaloView.alpha = isVisible ? 1 : 0
        orbMiddleHaloView.alpha = isVisible ? 1 : 0
        orbView.alpha = isVisible ? 1 : 0
    }

    private func setElapsedTextVisible(_ isVisible: Bool) {
        elapsedLabel.alpha = isVisible ? 1 : 0
        millisecondsLabel.alpha = isVisible ? 1 : 0
    }

    private func scheduleWaitingStateAfterFeedback() {
        cancelResultFeedback()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self, case .waiting = self.viewModel.phase else {
                return
            }

            self.setOrbPresentation(.waiting)
            self.instructionLabel.text = "대기하세요"
            self.instructionLabel.textColor = UIColor.white.withAlphaComponent(0.54)
        }
        resultFeedbackWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: workItem)
    }

    private func cancelResultFeedback() {
        resultFeedbackWorkItem?.cancel()
        resultFeedbackWorkItem = nil
    }

    private func startOrbRippleAnimation() {
        view.layoutIfNeeded()
        rippleView.alpha = 1
        rippleView.startAnimating()
    }

    private func startDisplayLink() {
        stopDisplayLink()
        let displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func displayLinkTick() {
        viewModel.updateElapsed()
    }

    @objc private func closeTapped() {
        onComplete(viewModel.summary)
    }

    @objc private func interruptTapped() {
        guard interruptDialogView.isHidden, interruptButton.alpha > 0 else {
            return
        }

        viewModel.pause()
        stopDisplayLink()
        rippleView.stopAnimating()
        cancelResultFeedback()
        showInterruptDialog()
    }

    @objc private func interruptCancelTapped() {
        hideInterruptDialog()
        viewModel.resume()

        if case .waiting = viewModel.phase {
            setOrbPresentation(.waiting)
        }
    }

    @objc private func interruptAbortTapped() {
        viewModel.stop()
        stopDisplayLink()
        rippleView.stopAnimating()
        cancelResultFeedback()
        onAbort()
    }

    private func showInterruptDialog() {
        interruptDimView.isHidden = false
        interruptDialogView.isHidden = false
        interruptDimView.alpha = 0
        interruptDialogView.alpha = 0
        interruptDialogView.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)

        UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut]) {
            self.interruptDimView.alpha = 1
            self.interruptDialogView.alpha = 1
            self.interruptDialogView.transform = .identity
        }
    }

    private func hideInterruptDialog() {
        UIView.animate(withDuration: 0.16, delay: 0, options: [.curveEaseIn]) {
            self.interruptDimView.alpha = 0
            self.interruptDialogView.alpha = 0
            self.interruptDialogView.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
        } completion: { _ in
            self.interruptDimView.isHidden = true
            self.interruptDialogView.isHidden = true
            self.interruptDialogView.transform = .identity
        }
    }

    private func configureMetric(titleLabel: UILabel, valueLabel: UILabel, title: String) {
        titleLabel.text = title
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.45)
        titleLabel.font = .systemFont(ofSize: 12, weight: .bold)
        titleLabel.letterSpacing = 1.2

        valueLabel.text = title == "LAPSE" ? "0" : "-- ms"
        valueLabel.textColor = .white
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 16, weight: .bold)
    }

    private func configureInterruptActionButton(
        _ button: UIButton,
        title: String,
        backgroundColor: UIColor,
        titleColor: UIColor,
        action: Selector
    ) {
        button.setTitle(title, for: .normal)
        button.setTitleColor(titleColor, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        button.backgroundColor = backgroundColor
        button.layer.cornerRadius = 14
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func applyOrbStyle(isStimulus: Bool) {
        if isStimulus {
            orbHaloView.backgroundColor = UIColor(red: 0.34, green: 0.29, blue: 0.24, alpha: 0.68)
            orbMiddleHaloView.backgroundColor = UIColor(red: 0.62, green: 0.51, blue: 0.28, alpha: 0.62)
            orbView.backgroundColor = PVTTheme.stimulus
            applyOrbGradient(colors: [
                UIColor(red: 1.0, green: 0.79, blue: 0.2, alpha: 1).cgColor,
                PVTTheme.stimulus.cgColor
            ])
        } else {
            orbHaloView.backgroundColor = PVTTheme.brandViolet.withAlphaComponent(0.18)
            orbMiddleHaloView.backgroundColor = PVTTheme.brandViolet.withAlphaComponent(0.32)
            orbView.backgroundColor = UIColor(hex: 0x5B8CFF)
            applyOrbGradient(colors: [
                UIColor(hex: 0x6EA8FF).cgColor,
                PVTTheme.brandViolet.cgColor
            ])
        }
    }

    private func applyOrbGradient(colors: [CGColor]) {
        orbView.layer.sublayers?
            .filter { $0.name == "stimulusGradient" }
            .forEach { $0.removeFromSuperlayer() }

        let gradient = CAGradientLayer()
        gradient.name = "stimulusGradient"
        gradient.frame = orbView.bounds
        gradient.colors = colors
        gradient.startPoint = CGPoint(x: 0.5, y: 0)
        gradient.endPoint = CGPoint(x: 0.5, y: 1)
        gradient.cornerRadius = orbView.bounds.height / 2
        orbView.layer.insertSublayer(gradient, at: 0)
    }
}

private extension UILabel {
    var letterSpacing: CGFloat {
        get { 0 }
        set {
            guard let labelText = text else {
                return
            }

            attributedText = NSAttributedString(
                string: labelText,
                attributes: [
                    .kern: newValue,
                    .font: font as Any,
                    .foregroundColor: textColor as Any
                ]
            )
        }
    }
}

private final class CircleView: UIView {
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(bounds.width, bounds.height) / 2
        layer.masksToBounds = true
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }

        context.setFillColor((backgroundColor ?? .clear).cgColor)
        context.fillEllipse(in: rect)
    }
}

private final class RippleWaveView: UIView {
    enum Style {
        case waiting
        case stimulus
    }

    private var displayLink: CADisplayLink?
    private var startTime: CFTimeInterval = 0
    private var style: Style = .stimulus

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        contentMode = .redraw
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setStyle(_ style: Style) {
        self.style = style
        setNeedsDisplay()
    }

    func startAnimating() {
        guard displayLink == nil else {
            return
        }

        startTime = CACurrentMediaTime()
        let displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
        setNeedsDisplay()
    }

    func stopAnimating() {
        displayLink?.invalidate()
        displayLink = nil
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard displayLink != nil, let context = UIGraphicsGetCurrentContext() else {
            return
        }

        let elapsed = CACurrentMediaTime() - startTime
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let diameter = min(bounds.width, bounds.height) * 0.82
        let cycleDuration: CFTimeInterval = style == .waiting ? 2.0 : 0.95
        let minRadius = diameter * 0.36
        let maxRadius = diameter * 0.49
        let offsets: [CFTimeInterval] = style == .waiting ? [0, 0.36, 0.72] : [0, 0.18, 0.36]
        let colors = colors(for: style)

        context.setBlendMode(.normal)

        for offset in offsets {
            let rawProgress = (elapsed - offset).truncatingRemainder(dividingBy: cycleDuration)
            let progress = rawProgress < 0 ? rawProgress + cycleDuration : rawProgress
            let normalizedProgress = CGFloat(progress / cycleDuration)

            let easedProgress = 1 - pow(1 - normalizedProgress, 1.75)
            let radius = minRadius + (maxRadius - minRadius) * easedProgress
            let alpha = max(0, (1 - normalizedProgress) * 0.45)
            let lineWidth = diameter * (0.13 - normalizedProgress * 0.055)

            let ringRect = CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )

            context.setStrokeColor(colors.primary.withAlphaComponent(alpha).cgColor)
            context.setLineWidth(lineWidth)
            context.strokeEllipse(in: ringRect)

            context.setStrokeColor(colors.secondary.withAlphaComponent(alpha * 0.32).cgColor)
            context.setLineWidth(lineWidth * 1.7)
            context.strokeEllipse(in: ringRect.insetBy(dx: -lineWidth * 0.32, dy: -lineWidth * 0.32))
        }
    }

    private func colors(for style: Style) -> (primary: UIColor, secondary: UIColor) {
        switch style {
        case .waiting:
            return (
                UIColor(red: 0.43, green: 0.66, blue: 1.0, alpha: 1),
                UIColor(red: 0.49, green: 0.36, blue: 1.0, alpha: 1)
            )

        case .stimulus:
            return (
                UIColor(red: 1.0, green: 0.74, blue: 0.20, alpha: 1),
                UIColor(red: 0.95, green: 0.45, blue: 0.02, alpha: 1)
            )
        }
    }

    @objc private func tick() {
        setNeedsDisplay()
    }
}
