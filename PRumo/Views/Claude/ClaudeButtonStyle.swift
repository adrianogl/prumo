import SwiftUI

struct ClaudeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(Color.claudeButtonText)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.claudeButtonBackground, in: RoundedRectangle(cornerRadius: 5))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
