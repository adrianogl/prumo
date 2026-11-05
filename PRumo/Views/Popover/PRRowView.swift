import SwiftUI
import AppKit
import PRumoKit

struct PRRowView: View {
    let pr: PullRequest
    let presentation: RowPresentation
    let tab: PopoverTab
    let model: AppModel
    @State private var hovering = false
    @State private var menuOpen = false

    private var claudePurpose: SessionPurpose? {
        switch tab {
        case .review: .review
        case .mine: pr.hasFailedCI ? .fixCI : nil
        }
    }

    private var actions: RowActions {
        RowActions(claudePurpose: claudePurpose) { model.launchClaude(pr: pr, purpose: $0) }
    }

    private func offersFix(badgeAt index: Int) -> Bool {
        tab == .mine && presentation.ciFailureBadgeIndex == index
    }

    private var accessibilitySummary: String {
        ([presentation.title, presentation.subtitle] + presentation.badges.map(\.text)).joined(separator: ", ")
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                NSWorkspace.shared.open(pr.url)
            } label: {
                Color.clear.contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilitySummary)
            .accessibilityAddTraits(.isButton)

            content

            if hovering || menuOpen || model.isLaunching(pr) {
                RowMenuButton(pr: pr, actions: actions, isLaunching: model.isLaunching(pr), menuOpen: $menuOpen)
                    .padding(.top, 6)
                    .padding(.trailing, 8)
            }
        }
        .background(hovering ? Color.primary.opacity(0.04) : Color.clear)
        .onHover { hovering = $0 }
        .contextMenu { RowMenuItems(pr: pr, actions: actions) }
    }

    private var content: some View {
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
                    .padding(.trailing, PopoverMetrics.menuReserve)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                Text(presentation.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                if !presentation.badges.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(Array(presentation.badges.enumerated()), id: \.offset) { index, badge in
                            BadgeView(badge: badge).allowsHitTesting(false).accessibilityHidden(true)
                            if offersFix(badgeAt: index), let purpose = claudePurpose {
                                fixButton(purpose)
                            }
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
    }

    private func fixButton(_ purpose: SessionPurpose) -> some View {
        Button {
            model.launchClaude(pr: pr, purpose: purpose)
        } label: {
            HStack(spacing: 3) {
                if model.isLaunching(pr) {
                    ProgressView().controlSize(.mini).scaleEffect(ClaudeMetrics.spinnerScale)
                        .frame(width: ClaudeMetrics.markSize, height: ClaudeMetrics.markSize)
                } else {
                    Image(ClaudeSymbol.mark)
                        .renderingMode(.original)
                        .resizable()
                        .frame(width: ClaudeMetrics.markSize, height: ClaudeMetrics.markSize)
                }
                Text(ClaudeText.fixBadge)
            }
        }
        .buttonStyle(ClaudeButtonStyle())
        .disabled(model.isLaunching(pr))
        .help(ClaudeText.fixCI)
        .accessibilityLabel(ClaudeText.fixCI)
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
