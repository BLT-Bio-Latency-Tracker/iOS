import SwiftUI

struct PVTMeasurementContainerView: UIViewControllerRepresentable {
    let environmentCalibration: PVTEnvironmentCalibrationResult?
    let onComplete: (PVTSummary) -> Void
    let onAbort: () -> Void

    init(
        environmentCalibration: PVTEnvironmentCalibrationResult? = nil,
        onComplete: @escaping (PVTSummary) -> Void,
        onAbort: @escaping () -> Void
    ) {
        self.environmentCalibration = environmentCalibration
        self.onComplete = onComplete
        self.onAbort = onAbort
    }

    func makeUIViewController(context: Context) -> PVTMeasurementViewController {
        PVTMeasurementViewController(
            viewModel: PVTTestViewModel(environmentCalibration: environmentCalibration),
            onComplete: onComplete,
            onAbort: onAbort
        )
    }

    func updateUIViewController(_ uiViewController: PVTMeasurementViewController, context: Context) {
    }
}
