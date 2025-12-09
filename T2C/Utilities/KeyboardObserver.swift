//
//  KeyboardObserver.swift
//  T2C
//
//  Adjusts UI when the system keyboard appears.
//

import Combine
import SwiftUI
import UIKit

final class KeyboardObserver: ObservableObject {

    @Published var height: CGFloat = 0

    private var cancellables = Set<AnyCancellable>()

    init() {
        let willChange = NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)
        let willHide = NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)

        willChange
            .merge(with: willHide)
            .compactMap { notification in
                notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            }
            .sink { [weak self] endFrame in
                guard let self else { return }

                let screenHeight = UIApplication.shared.firstKeyWindow?.windowScene?.screen.bounds.height ?? endFrame.maxY
                let overlap = max(0, screenHeight - endFrame.origin.y)
                let safeBottom = UIApplication.shared.firstKeyWindow?.safeAreaInsets.bottom ?? 0

                withAnimation(.easeInOut(duration: 0.25)) {
                    self.height = max(0, overlap - safeBottom)
                }
            }
            .store(in: &cancellables)
    }
}

private extension UIApplication {
    var firstKeyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
