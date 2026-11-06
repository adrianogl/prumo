import SwiftUI

struct PillButtonStyle: ButtonStyle {
    var isProminent = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(isProminent ? Color.white : Color.primary)
            .background(isProminent ? Color.prumoCaramel : Color.windowCard, in: Capsule())
            .overlay(Capsule().stroke(isProminent ? Color.clear : Color.windowLine))
            .opacity(configuration.isPressed ? 0.7 : (isEnabled ? 1 : 0.45))
            .contentShape(Capsule())
    }
}
