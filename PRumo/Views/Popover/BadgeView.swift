import SwiftUI
import PRumoKit

extension BadgeTone {
    var color: Color {
        switch self {
        case .positive: Color(nsColor: .systemGreen)
        case .negative: Color(nsColor: .systemRed)
        case .pending: Color(nsColor: .systemYellow)
        case .warning: Color(nsColor: .systemOrange)
        case .neutral: Color.secondary
        }
    }
}

extension BadgeIcon {
    var systemName: String? {
        switch self {
        case .none: nil
        case .comments: PopoverSymbol.comments
        case .conflict: PopoverSymbol.conflict
        case .clock: PopoverSymbol.clock
        }
    }
}

extension StatusDot {
    var color: Color {
        switch self {
        case .ok: Color(nsColor: .systemGreen)
        case .running: Color(nsColor: .systemYellow)
        case .failed: Color(nsColor: .systemRed)
        case .attention: Color(nsColor: .systemOrange)
        }
    }
}

struct BadgeView: View {
    let badge: Badge

    var body: some View {
        HStack(spacing: 3) {
            if let name = badge.icon.systemName {
                Image(systemName: name).font(.system(size: 10))
            }
            Text(badge.text)
                .lineLimit(1)
        }
        .fixedSize()
        .font(.system(size: 10.5, weight: .medium))
        .foregroundStyle(badge.tone.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.prumoBadgeBackground, in: RoundedRectangle(cornerRadius: 5))
    }
}
