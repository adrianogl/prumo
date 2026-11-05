import SwiftUI
import AppKit
import PRumoKit

struct PRRowView: View {
    let pr: PullRequest
    let presentation: RowPresentation
    @State private var hovering = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(pr.url)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(presentation.dot.color)
                    .frame(width: PopoverMetrics.dotSize, height: PopoverMetrics.dotSize)
                    .padding(.top, 4)
                VStack(alignment: .leading, spacing: 3) {
                    Text(presentation.title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text(presentation.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    if !presentation.badges.isEmpty {
                        HStack(spacing: 5) {
                            ForEach(Array(presentation.badges.enumerated()), id: \.offset) { _, badge in
                                BadgeView(badge: badge)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(hovering ? Color.primary.opacity(0.04) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct PRRowSkeleton: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(.quaternary).frame(width: PopoverMetrics.dotSize, height: PopoverMetrics.dotSize).padding(.top, 4)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 3).fill(.quaternary).frame(height: 12)
                RoundedRectangle(cornerRadius: 3).fill(.quaternary).frame(width: 140, height: 9)
                RoundedRectangle(cornerRadius: 3).fill(.quaternary).frame(width: 90, height: 14)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}
