import AppKit
import Observation
import PRumoKit
import SwiftTerm

@Observable @MainActor
final class TerminalSessionStore {
    private(set) var registry = TerminalSessionRegistry()
    var isPanelVisible = true
    @ObservationIgnored private var views: [UUID: LocalProcessTerminalView] = [:]
    @ObservationIgnored private var delegates: [UUID: AnyObject] = [:]
    @ObservationIgnored var onExit: ((TerminalSessionInfo) -> Void)?

    func view(for id: UUID) -> LocalProcessTerminalView? {
        views[id]
    }

    func start(_ info: TerminalSessionInfo, script: URL) {
        if let previous = registry.session(forPullRequest: info.pullRequestID) { discardView(previous.id) }
        let view = LocalProcessTerminalView(frame: NSRect(x: 0, y: 0, width: 800, height: 300))
        view.font = NSFont.monospacedSystemFont(ofSize: TerminalMetrics.fontSize, weight: .regular)
        let id = info.id
        let process = ProcessObserver { [weak self] code in self?.processExited(id, code: code) }
        let bell = BellForwardingDelegate(base: view) { [weak self] in self?.registry.bell(id) }
        view.processDelegate = process
        view.terminalDelegate = bell
        views[id] = view
        delegates[id] = [process, bell] as AnyObject
        registry.add(info)
        isPanelVisible = true
        let command = TerminalCommand.embedded(scriptPath: script)
        view.startProcess(
            executable: command.executable, args: command.arguments,
            environment: Terminal.getEnvironmentVariables(termName: TerminalMetrics.termName),
            currentDirectory: info.directory.path)
    }

    func focus(_ id: UUID) {
        registry.focus(id)
    }

    func focus(pullRequest id: String) {
        registry.focus(pullRequest: id)
    }

    func focusNext() {
        guard let next = registry.next(after: registry.focusedID) else { return }
        registry.focus(next)
    }

    func close(_ id: UUID) {
        discardView(id)
        registry.close(id)
    }

    func terminateAll() {
        for session in registry.sessions where session.status.isAlive {
            views[session.id]?.terminate()
        }
    }

    private func discardView(_ id: UUID) {
        if registry.session(id: id)?.status.isAlive == true { views[id]?.terminate() }
        views[id] = nil
        delegates[id] = nil
    }

    private func processExited(_ id: UUID, code: Int32?) {
        let exitCode = code ?? TerminalMetrics.signalExitCode
        registry.exited(id, code: exitCode)
        views[id]?.feed(text: TerminalText.exitedBanner(exitCode))
        if let info = registry.session(id: id) { onExit?(info) }
    }
}

@MainActor
private final class ProcessObserver: LocalProcessTerminalViewDelegate {
    private let onExit: (Int32?) -> Void

    init(onExit: @escaping (Int32?) -> Void) {
        self.onExit = onExit
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        onExit(exitCode)
    }

    func processFailedToStart(source: TerminalView, error: LocalProcessError) {
        onExit(nil)
    }
}
