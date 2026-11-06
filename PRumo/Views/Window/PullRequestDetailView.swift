import SwiftUI
import PRumoKit

struct PullRequestDetailView: View {
    let pr: PullRequest
    let presentation: RowPresentation
    let entries: [RowMenuEntry]
    let now: Date
    let isLaunching: Bool
    let perform: (RowMenuEntry) -> Void

    private var claudeEntries: [RowMenuEntry] {
        entries.filter { if case .claude = $0 { true } else { false } }
    }

    private var otherEntries: [RowMenuEntry] {
        entries.filter {
            switch $0 {
            case .openJira, .rerunFailedJobs, .cancelAndRerun: true
            default: false
            }
        }
    }

    private var markEntries: [RowMenuEntry] {
        entries.filter {
            switch $0 {
            case .copyLink, .copyCheckout, .pin, .mute: true
            default: false
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DetailMetrics.spacing) {
                header
                badges
                actions
                HStack(alignment: .top, spacing: DetailMetrics.columnSpacing) {
                    section(DetailText.checks) { checks }
                    section(DetailText.reviews) { reviews }
                }
                section(DetailText.activity) { activity }
            }
            .padding(.horizontal, DetailMetrics.padding)
            .padding(.top, MainWindowMetrics.sidebarTopInset)
            .padding(.bottom, DetailMetrics.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.prumoPopoverBackground)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(presentation.dot.color)
                    .frame(width: DetailMetrics.stateDotSize, height: DetailMetrics.stateDotSize)
                Text("\(RepositoryCatalog.displayName(pr.repositoryKey)) \(pr.reference) · \(DetailText.updated(RelativeAge.string(from: pr.updatedAt, now: now)))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if pr.isDraft {
                    Text(DetailText.draft)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Text(pr.title)
                .font(.system(size: DetailMetrics.titleFontSize, weight: .semibold))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var badges: some View {
        if !presentation.badges.isEmpty {
            FlowLayout(spacing: PopoverMetrics.badgeSpacing, lineSpacing: PopoverMetrics.badgeLineSpacing) {
                ForEach(Array(presentation.badges.enumerated()), id: \.offset) { index, badge in
                    BadgeView(badge: badge, tint: index == presentation.jiraBadgeIndex ? Color.jiraBlue : nil)
                }
            }
        }
    }

    private var actions: some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            Button(RowMenuText.openInBrowser) { perform(.openInBrowser) }
                .buttonStyle(PillButtonStyle(isProminent: true))
                .fixedSize()
            if !claudeEntries.isEmpty {
                Menu {
                    ForEach(Array(claudeEntries.enumerated()), id: \.offset) { _, entry in
                        Button(entry.title) { perform(entry) }
                            .keyboardShortcut(entry.keyboardShortcut)
                    }
                } label: {
                    Label(DetailText.claude, systemImage: DetailSymbol.claude)
                        .font(.system(size: 12, weight: .medium))
                }
                .menuStyle(.button)
                .buttonStyle(PillButtonStyle())
                .fixedSize()
                .disabled(isLaunching)
            }
            ForEach(Array(otherEntries.enumerated()), id: \.offset) { _, entry in
                Button(entry.title) { perform(entry) }
                    .help(entry.help ?? "")
                    .disabled(isDisabled(entry))
                    .buttonStyle(PillButtonStyle())
                    .fixedSize()
            }
            Menu {
                ForEach(Array(markEntries.enumerated()), id: \.offset) { _, entry in
                    Button(entry.title) { perform(entry) }
                        .keyboardShortcut(entry.keyboardShortcut)
                        .help(entry.help ?? "")
                }
            } label: {
                Image(systemName: ClaudeSymbol.more)
            }
            .menuStyle(.button)
            .buttonStyle(PillButtonStyle())
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel(DetailText.more)
        }
        .controlSize(.regular)
    }

    private func isDisabled(_ entry: RowMenuEntry) -> Bool {
        switch entry {
        case .rerunFailedJobs(_, _, let reason), .cancelAndRerun(let reason): reason != nil
        default: false
        }
    }

    @ViewBuilder
    private var checks: some View {
        if pr.checks.isEmpty {
            emptyRow(DetailText.noChecks)
        } else {
            ForEach(Array(pr.checks.enumerated()), id: \.offset) { index, check in
                if index > 0 { Divider() }
                line(symbol: check.state.symbol, color: check.state.color, text: check.name,
                     trailing: check.duration.map(DetailText.duration), url: check.url)
            }
        }
    }

    @ViewBuilder
    private var reviews: some View {
        let latest = ReviewerStatus.latest(pr.reviews)
        if latest.isEmpty {
            emptyRow(DetailText.noReviews)
        } else {
            ForEach(Array(latest.enumerated()), id: \.offset) { index, review in
                if index > 0 { Divider() }
                line(symbol: review.state.detailSymbol, color: review.state.detailColor, text: "@\(review.author)",
                     trailing: review.state.detailLabel, url: review.url)
            }
        }
    }

    @ViewBuilder
    private var activity: some View {
        let items = PullRequestActivity.items(for: pr)
        if items.isEmpty {
            emptyRow(DetailText.noActivity)
        } else {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                if index > 0 { Divider() }
                line(symbol: item.kind.symbol, color: item.kind.color, text: item.kind.text(actor: item.actor),
                     trailing: DetailText.ago(RelativeAge.string(from: item.date, now: now)), url: item.url)
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: DetailMetrics.sectionFontSize, weight: .semibold))
                .foregroundStyle(.secondary)
                .tracking(0.4)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.windowCard, in: RoundedRectangle(cornerRadius: DetailMetrics.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: DetailMetrics.cardRadius).stroke(Color.windowLine))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func line(symbol: String, color: Color, text: String, trailing: String?, url: URL?) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 14)
            Text(text)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: DetailMetrics.rowFontSize))
        .padding(DetailMetrics.rowPadding)
        .contentShape(Rectangle())
        .onTapGesture { if let url { NSWorkspace.shared.open(url) } }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(url == nil ? [] : .isLink)
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: DetailMetrics.rowFontSize))
            .foregroundStyle(.secondary)
            .padding(DetailMetrics.rowPadding)
    }
}
