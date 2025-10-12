//
//  T2CApp.swift
//  T2C
//
//  Created by Yumi Izumi on 2025/10/12.
//

import SwiftUI

@main
struct T2CApp: App {

    init() {
        // Suppress simulator haptic warnings
        HapticUtil.disableKeyboardHaptics()
    }

    var body: some Scene {
        WindowGroup {
            MainView()
        }
    }
}
