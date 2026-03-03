//
//  ToastView.swift
//  T2C
//
//  Lightweight toast notification for save confirmation feedback
//

import SwiftUI

/// A pill-shaped toast notification that displays a brief confirmation message.
///
/// Shows a green checkmark icon alongside a single-line message string,
/// rendered on a blurred material background with a capsule clip and drop shadow.
/// Accessibility: the icon is hidden from VoiceOver and the container presents
/// the message as a single combined element.
struct ToastView: View {

    /// The confirmation text displayed inside the toast (e.g. "Lunch — Today at 12:00 PM").
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.system(size: 18, weight: .semibold))
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }
}

#Preview {
    ToastView(message: "Lunch — Tomorrow 12:00 PM")
        .padding()
}
