import SwiftUI

struct PVTMeasurementContainerView: UIViewControllerRepresentable {
    let onComplete: (PVTSummary) -> Void
    let onAbort: () -> Void

    func makeUIViewController(context: Context) -> PVTMeasurementViewController {
        PVTMeasurementViewController(
            viewModel: PVTTestViewModel(),
            onComplete: onComplete,
            onAbort: onAbort
        )
    }

    func updateUIViewController(_ uiViewController: PVTMeasurementViewController, context: Context) {
    }
}
