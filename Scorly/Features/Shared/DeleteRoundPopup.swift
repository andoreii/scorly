//
// DeleteRoundPopup.swift
// Custom centered popup for round deletion confirmation.
//

import SwiftUI

struct DeleteRoundPopup: View {
    let onDelete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            // Dim overlay
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            // Card
            VStack(spacing: 0) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color(red: 0.88, green: 0.28, blue: 0.24).opacity(0.12))
                        .frame(width: 64, height: 64)
                    Image(systemName: "trash.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color(red: 0.88, green: 0.28, blue: 0.24))
                }
                .padding(.top, 28)

                // Title
                Text("Delete Round?")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.top, 16)

                // Message
                Text("All progress will be permanently lost.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.black.opacity(0.45))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 6)

                // Buttons
                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.black.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)

                    Button(action: onDelete) {
                        Text("Delete")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(red: 0.88, green: 0.28, blue: 0.24))
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            .frame(width: 300)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.18), radius: 30, y: 10)
            )
            .transition(.scale(scale: 0.88).combined(with: .opacity))
        }
    }
}
