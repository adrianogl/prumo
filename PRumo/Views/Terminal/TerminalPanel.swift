import SwiftUI
import PRumoKit

struct TerminalPanel: View {
    let store: TerminalSessionStore
    let select: (TerminalSessionInfo) -> Void
    @State private var pendingClose: UUID?

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            TerminalHostView(terminal: store.registry.focusedID.flatMap(store.view(for:)))
                .frame(minHeight: TerminalMetrics.panelMinHeight)
        }
        .confirmationDialog(
            TerminalText.closeTitle, isPresented: isConfirmingClose, titleVisibility: .visible
        ) {
            Button(TerminalText.closeConfirm, role: .destructive) {
                if let pendingClose { store.close(pendingClose) }
                pendingClose = nil
            }
            Button(TerminalText.cancel, role: .cancel) { pendingClose = nil }
        } message: {
            Text(TerminalText.closeMessage)
        }
    }

    private var isConfirmingClose: Binding<Bool> {
        Binding(get: { pendingClose != nil }, set: { if !$0 { pendingClose = nil } })
    }

    private var tabBar: some View {
        HStack(spacing: TerminalMetrics.tabSpacing) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: TerminalMetrics.tabSpacing) {
                    ForEach(store.registry.sessions) { session in
                        tab(session)
                    }
                }
            }
            Spacer(minLength: 8)
            Button {
                store.isPanelVisible = false
            } label: {
                Image(systemName: TerminalSymbol.collapse)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help(TerminalText.togglePanel)
            .accessibilityLabel(TerminalText.togglePanel)
        }
        .padding(.horizontal, 8)
        .frame(height: TerminalMetrics.tabBarHeight)
        .background(.bar)
    }

    private func tab(_ session: TerminalSessionInfo) -> some View {
        let isFocused = store.registry.focusedID == session.id
        return HStack(spacing: 6) {
            Button {
                store.focus(session.id)
                select(session)
            } label: {
                HStack(spacing: 6) {
                    Circle()
                        .fill(session.status.color)
                        .frame(width: TerminalMetrics.tabDotSize, height: TerminalMetrics.tabDotSize)
                    Text(TerminalText.tabTitle(session))
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
            .help(session.status.label)
            Button {
                if session.status.isAlive { pendingClose = session.id } else { store.close(session.id) }
            } label: {
                Image(systemName: TerminalSymbol.close)
                    .font(.system(size: 9, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel(TerminalText.closeTab)
        }
        .font(.system(size: 11.5))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(isFocused ? Color.prumoPopoverBackground : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        .foregroundStyle(isFocused ? Color.primary : Color.secondary)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(TerminalText.tabTitle(session)), \(session.status.label)")
    }
}
