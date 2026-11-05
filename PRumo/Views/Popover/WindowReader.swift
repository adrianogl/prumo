import SwiftUI
import AppKit

struct WindowReader: NSViewRepresentable {
    let onChange: (NSWindow?) -> Void

    func makeNSView(context: Context) -> WindowReaderView {
        let view = WindowReaderView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ view: WindowReaderView, context: Context) {
        view.onChange = onChange
    }
}

final class WindowReaderView: NSView {
    var onChange: (NSWindow?) -> Void = { _ in }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        let window = window
        let onChange = onChange
        Task { @MainActor in onChange(window) }
    }
}
