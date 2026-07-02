import SwiftUI
import UIKit

extension View {
    func enablesInteractivePopGesture() -> some View {
        background(InteractivePopGestureEnabler())
    }
}

private struct InteractivePopGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        InteractivePopGestureViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        (uiViewController as? InteractivePopGestureViewController)?.enableInteractivePopGesture()
    }
}

private final class InteractivePopGestureViewController: UIViewController {
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        enableInteractivePopGesture()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        enableInteractivePopGesture()
    }

    func enableInteractivePopGesture() {
        guard let navigationController else { return }

        navigationController.interactivePopGestureRecognizer?.isEnabled = true
        navigationController.interactivePopGestureRecognizer?.delegate = nil
    }
}
