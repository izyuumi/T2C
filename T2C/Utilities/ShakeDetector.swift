//
//  ShakeDetector.swift
//  T2C
//
//  Detects device shake gesture and triggers an action.
//

import SwiftUI
import UIKit

/// A UIViewController subclass that detects shake gestures
final class ShakeDetectingViewController: UIViewController {
    var onShake: (() -> Void)?

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            onShake?()
        }
    }
}

/// SwiftUI representable that bridges UIKit shake detection
struct ShakeDetector: UIViewControllerRepresentable {
    let onShake: () -> Void

    func makeUIViewController(context: Context) -> ShakeDetectingViewController {
        let vc = ShakeDetectingViewController()
        vc.onShake = onShake
        return vc
    }

    func updateUIViewController(_ uiViewController: ShakeDetectingViewController, context: Context) {
        uiViewController.onShake = onShake
    }
}

extension View {
    /// Adds a shake-to-perform action to any view
    func onShake(perform action: @escaping () -> Void) -> some View {
        self.background(ShakeDetector(onShake: action))
    }
}
