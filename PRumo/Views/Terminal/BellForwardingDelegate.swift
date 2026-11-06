import AppKit
import SwiftTerm

@MainActor
final class BellForwardingDelegate: TerminalViewDelegate {
    private weak var base: LocalProcessTerminalView?
    private let onBell: () -> Void

    init(base: LocalProcessTerminalView, onBell: @escaping () -> Void) {
        self.base = base
        self.onBell = onBell
    }

    func bell(source: TerminalView) {
        onBell()
    }

    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        base?.sizeChanged(source: source, newCols: newCols, newRows: newRows)
    }

    func setTerminalTitle(source: TerminalView, title: String) {
        base?.setTerminalTitle(source: source, title: title)
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {
        base?.hostCurrentDirectoryUpdate(source: source, directory: directory)
    }

    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        base?.send(source: source, data: data)
    }

    func scrolled(source: TerminalView, position: Double) {
        base?.scrolled(source: source, position: position)
    }

    func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {
        base?.requestOpenLink(source: source, link: link, params: params)
    }

    func clipboardCopy(source: TerminalView, content: Data) {
        base?.clipboardCopy(source: source, content: content)
    }

    func clipboardRead(source: TerminalView) -> Data? {
        base?.clipboardRead(source: source)
    }

    func kittyClipboardCapabilities(source: TerminalView) -> KittyClipboardCapabilities {
        guard let base else { return [] }
        return base.kittyClipboardCapabilities(source: source)
    }

    func kittyClipboardAvailableMimeTypes(source: TerminalView, location: KittyClipboardLocation) -> [String]? {
        base?.kittyClipboardAvailableMimeTypes(source: source, location: location)
    }

    func kittyClipboardRead(source: TerminalView, location: KittyClipboardLocation, mimeType: String) -> KittyClipboardReadResult? {
        base?.kittyClipboardRead(source: source, location: location, mimeType: mimeType)
    }

    func kittyClipboardWrite(
        source: TerminalView, location: KittyClipboardLocation, content: KittyClipboardWriteContent
    ) -> KittyClipboardWriteResult {
        guard let base else { return .unsupported }
        return base.kittyClipboardWrite(source: source, location: location, content: content)
    }

    func kittyClipboardRequestPermission(
        source: TerminalView, request: KittyClipboardPermissionRequest
    ) -> KittyClipboardPermissionResult {
        guard let base else { return .deny }
        return base.kittyClipboardRequestPermission(source: source, request: request)
    }

    func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {
        base?.iTermContent(source: source, content: content)
    }

    func rangeChanged(source: TerminalView, startY: Int, endY: Int) {
        base?.rangeChanged(source: source, startY: startY, endY: endY)
    }

    func programStatusChanged(source: TerminalView, records: [TerminalProgramStatus]) {
        base?.programStatusChanged(source: source, records: records)
    }
}
