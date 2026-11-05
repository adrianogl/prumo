import SwiftUI
import AppKit
import PRumoKit

struct PRRowView: View {
    let pr: PullRequest
    let presentation: RowPresentation
    let compactLine: String?
    let tab: ListTab
    let isHighlighted: Bool
    let model: AppModel
    @State private var hovering = false
    @State private var menuOpen = false

    private static let dayMonth: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = PopoverText.dayMonthFormat
        return formatter
    }()

    private var isPinned: Bool { model.organization.settings.marks.isPinned(pr.id) }
    private var muted: MutedPullRequest? { model.organization.settings.marks.muted[pr.id] }
    private var showsMenu: Bool { hovering || menuOpen || model.isLaunching(pr) }

    private var actions: RowActions {
        let purposes = pr.claudePurposes(in: tab, offersComments: presentation.commentsBadgeIndex != nil)
        let entries = RowMenuPlan.entries(
            pr: pr, claudePurposes: purposes, jira: model.integrations.link(for: pr),
            isPinned: isPinned, isMuted: muted != nil)
        return RowActions(entries: entries) { model.perform($0, on: pr) }
    }

    private func purpose(forBadgeAt index: Int) -> SessionPurpose? {
        guard tab == .mine else { return nil }
        if presentation.ciFailureBadgeIndex == index { return .fixCI }
        if presentation.conflictBadgeIndex == index { return .resolveConflict }
        if presentation.commentsBadgeIndex == index { return .addressComments }
        return nil
    }

    private var accessibilitySummary: String {
        let details = compactLine.map { [$0] } ?? [presentation.subtitle] + presentation.badges.map(\.text)
        return ([presentation.title] + details).joined(separator: ", ")
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let muted {
                openButton
                    .help(PopoverText.mutedOn(date: Self.dayMonth.string(from: muted.mutedAt)))
                content
                    .opacity(PopoverMetrics.mutedOpacity)
            } else {
                openButton
                content
            }

            if showsMenu {
                RowMenuButton(
                    actions: actions, isLaunching: model.isLaunching(pr), isRerunning: model.isRerunning(pr),
                    menuOpen: $menuOpen)
                    .padding(.top, 6)
                    .padding(.trailing, 8)
            } else if isHighlighted {
                Circle()
                    .fill(Color.prumoCaramel)
                    .frame(width: PopoverMetrics.newDotSize, height: PopoverMetrics.newDotSize)
                    .frame(width: ClaudeMetrics.menuButtonSize, height: ClaudeMetrics.menuButtonSize)
                    .padding(.top, 6)
                    .padding(.trailing, 8)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .background(hovering ? Color.primary.opacity(0.04) : Color.clear)
        .onHover { hovering = $0 }
        .contextMenu { RowMenuItems(actions: actions, isRerunning: model.isRerunning(pr)) }
    }

    private var openButton: some View {
        Button {
            NSWorkspace.shared.open(pr.url)
        } label: {
            Color.clear.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilitySummary)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var statusMark: some View {
        if muted != nil {
            Image(systemName: PopoverSymbol.muted)
                .font(.system(size: PopoverMetrics.dotSize))
                .foregroundStyle(.secondary)
                .frame(width: PopoverMetrics.dotSize, height: PopoverMetrics.dotSize)
                .padding(.top, 4)
        } else {
            Circle()
                .fill(presentation.dot.color)
                .frame(width: PopoverMetrics.dotSize, height: PopoverMetrics.dotSize)
                .padding(.top, 4)
        }
    }

    private var titleLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            if isPinned {
                Image(systemName: PopoverSymbol.pinned)
                    .font(.system(size: PopoverMetrics.pinSize))
                    .foregroundStyle(Color.prumoCaramel)
            }
            Text(presentation.title)
                .font(.system(size: 13, weight: isHighlighted ? .semibold : .medium))
                .lineLimit(compactLine == nil ? 2 : 1)
                .multilineTextAlignment(.leading)
        }
        .padding(.trailing, PopoverMetrics.menuReserve)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var content: some View {
        HStack(alignment: .top, spacing: 10) {
            statusMark
            VStack(alignment: .leading, spacing: 3) {
                titleLine
                Text(compactLine ?? presentation.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(compactLine == nil ? nil : 1)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                if compactLine == nil, !presentation.badges.isEmpty {
                    FlowLayout(spacing: PopoverMetrics.badgeSpacing, lineSpacing: PopoverMetrics.badgeLineSpacing) {
                        ForEach(Array(presentation.badges.enumerated()), id: \.offset) { index, badge in
                            BadgeView(badge: badge).allowsHitTesting(false).accessibilityHidden(true)
                            if let purpose = purpose(forBadgeAt: index) {
                                claudeButton(purpose)
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

    private func claudeButton(_ purpose: SessionPurpose) -> some View {
        Button {
            model.launchClaude(pr: pr, purpose: purpose)
        } label: {
            HStack(spacing: 3) {
                if model.isLaunching(pr) {
                    ProgressView().controlSize(.mini).scaleEffect(ClaudeMetrics.spinnerScale)
                        .frame(width: ClaudeMetrics.markSize, height: ClaudeMetrics.markSize)
                } else {
                    Image(ClaudeSymbol.mark)
                        .renderingMode(.template)
                        .resizable()
                        .foregroundStyle(Color.claudeMark)
                        .frame(width: ClaudeMetrics.markSize, height: ClaudeMetrics.markSize)
                }
                Text(purpose.badgeTitle)
                    .lineLimit(1)
            }
            .fixedSize()
        }
        .buttonStyle(ClaudeButtonStyle())
        .disabled(model.isLaunching(pr))
        .help(purpose.menuTitle)
        .accessibilityLabel(purpose.menuTitle)
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
