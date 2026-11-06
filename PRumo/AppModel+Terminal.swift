import AppKit
import PRumoKit

extension AppModel {
    func showTerminal(forPullRequest id: String) {
        terminals.focus(pullRequest: id)
        windowFocusRequest = id
        mainWindow.open()
    }

    func prepareEmbeddedLaunch(pr: PullRequest, purpose: SessionPurpose) -> Bool {
        switch terminals.registry.decision(forPullRequest: pr.id, purpose: purpose) {
        case .create:
            return true
        case .focus:
            showTerminal(forPullRequest: pr.id)
            return false
        case .askToReplace(let id):
            guard let current = terminals.registry.session(id: id), confirmReplace(current) else { return false }
            terminals.close(id)
            return true
        }
    }

    func startEmbedded(pr: PullRequest, purpose: SessionPurpose, directory: URL, script: URL) {
        let info = TerminalSessionInfo(
            pullRequestID: pr.id, reference: pr.reference, purpose: purpose, directory: directory, startedAt: .now)
        terminals.start(info, script: script)
        showTerminal(forPullRequest: pr.id)
    }

    func confirmQuitWithLiveSessions() -> Bool {
        guard terminals.registry.hasLiveSessions else { return true }
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = TerminalText.quitTitle
        alert.informativeText = TerminalText.quitMessage
        alert.addButton(withTitle: TerminalText.quitConfirm)
        alert.addButton(withTitle: TerminalText.cancel)
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        terminals.terminateAll()
        return true
    }

    private func confirmReplace(_ current: TerminalSessionInfo) -> Bool {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = TerminalText.replaceTitle
        alert.informativeText = TerminalText.replaceMessage(current: TerminalText.tabTitle(current))
        alert.addButton(withTitle: TerminalText.replaceConfirm)
        alert.addButton(withTitle: TerminalText.cancel)
        return alert.runModal() == .alertFirstButtonReturn
    }
}
