//
//  HapticUtil.swift
//  T2C
//
//  Utilities for managing haptic feedback and suppressing simulator warnings
//

import UIKit
import OSLog

private let logger = OSLog(subsystem: "com.t2c.app", category: "HapticUtil")

struct HapticUtil {

    /// Play success haptic feedback (if enabled in settings)
    static func playSuccess() {
        guard UserDefaults.standard.object(forKey: "hapticFeedback") as? Bool ?? true else { return }
        #if !targetEnvironment(simulator)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }

    /// Play error haptic feedback (if enabled in settings)
    static func playError() {
        guard UserDefaults.standard.object(forKey: "hapticFeedback") as? Bool ?? true else { return }
        #if !targetEnvironment(simulator)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
        #endif
    }

    /// Disables keyboard haptic feedback to suppress simulator warnings
    /// This only affects the simulator - real devices will still have haptics
    static func disableKeyboardHaptics() {
        #if targetEnvironment(simulator)
        os_log(.info, log: logger, "Attempting to disable keyboard haptics for simulator")

        // Try multiple known UserDefaults keys
        let keys = [
            "UITextFieldEnableFeedback",
            "UITextViewEnableFeedback",
            "UIKeyboardEnableFeedback",
            "UITextInputEnableFeedback",
            "com.apple.keyboard.feedback.enabled"
        ]

        for key in keys {
            UserDefaults.standard.set(false, forKey: key)
        }

        // Also try setting in standard user defaults domain
        UserDefaults.standard.set(false, forKey: "UIFeedbackEnabled")
        UserDefaults.standard.synchronize()

        os_log(.info, log: logger, "Keyboard haptic suppression configured")

        // Log warning that simulator errors may still appear
        os_log(.info, log: logger, "Note: CHHapticPattern warnings may still appear in simulator console - these are harmless and don't affect functionality")
        #endif
    }

    /// Re-enables keyboard haptic feedback (typically not needed)
    static func enableKeyboardHaptics() {
        UserDefaults.standard.removeObject(forKey: "UITextFieldEnableFeedback")
        UserDefaults.standard.removeObject(forKey: "UITextViewEnableFeedback")
        UserDefaults.standard.removeObject(forKey: "UIKeyboardEnableFeedback")
        UserDefaults.standard.removeObject(forKey: "UITextInputEnableFeedback")
        UserDefaults.standard.removeObject(forKey: "com.apple.keyboard.feedback.enabled")
        UserDefaults.standard.removeObject(forKey: "UIFeedbackEnabled")
    }
}
