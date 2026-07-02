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
    private weak var originalPopGestureDelegate: UIGestureRecognizerDelegate?
    private var didOverridePopGestureDelegate = false

    deinit {
        restoreInteractivePopGestureDelegate()
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        enableInteractivePopGesture()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        enableInteractivePopGesture()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreInteractivePopGestureDelegate()
    }

    func enableInteractivePopGesture() {
        guard let popGesture = navigationController?.interactivePopGestureRecognizer else { return }

        if !didOverridePopGestureDelegate {
            originalPopGestureDelegate = popGesture.delegate
            didOverridePopGestureDelegate = true
        }

        popGesture.isEnabled = true
        popGesture.delegate = nil
    }

    private func restoreInteractivePopGestureDelegate() {
        guard didOverridePopGestureDelegate,
              let popGesture = navigationController?.interactivePopGestureRecognizer else { return }

        popGesture.delegate = originalPopGestureDelegate
        originalPopGestureDelegate = nil
        didOverridePopGestureDelegate = false
    }
}
