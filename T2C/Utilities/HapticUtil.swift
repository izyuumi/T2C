//
//  HapticUtil.swift
//  T2C
//
//  Utilities for managing haptic feedback and suppressing simulator warnings
//

import UIKit

struct HapticUtil {

    /// Disables keyboard haptic feedback to suppress simulator warnings
    /// This only affects the simulator - real devices will still have haptics
    static func disableKeyboardHaptics() {
        #if targetEnvironment(simulator)
        // Disable UIKit keyboard feedback generator to suppress CHHapticPattern errors
        UserDefaults.standard.set(false, forKey: "UITextFieldEnableFeedback")
        UserDefaults.standard.set(false, forKey: "UITextViewEnableFeedback")
        #endif
    }

    /// Re-enables keyboard haptic feedback (typically not needed)
    static func enableKeyboardHaptics() {
        UserDefaults.standard.removeObject(forKey: "UITextFieldEnableFeedback")
        UserDefaults.standard.removeObject(forKey: "UITextViewEnableFeedback")
    }
}
