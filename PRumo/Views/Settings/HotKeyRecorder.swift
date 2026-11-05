import AppKit
import Carbon.HIToolbox
import SwiftUI
import PRumoKit

struct HotKeyRecorder: View {
    let model: AppModel
    @State private var isRecording = false
    @State private var warning: String?
    @State private var monitor: Any?

    var body: some View {
        LabeledContent(SettingsText.hotKey) {
            VStack(alignment: .trailing, spacing: SettingsMetrics.hotKeyRecorderSpacing) {
                HStack {
                    Button(action: toggleRecording) {
                        Text(isRecording ? SettingsText.hotKeyRecording : model.hotKey.display)
                            .font(.system(size: SettingsMetrics.hotKeyFontSize, design: isRecording ? .default : .monospaced))
                            .frame(minWidth: SettingsMetrics.hotKeyButtonWidth)
                    }
                    Button(SettingsText.hotKeyRestore) {
                        stopRecording()
                        apply(.standard)
                    }
                    .disabled(model.hotKey == .standard)
                }
                if let warning {
                    Text(warning).font(.system(size: SettingsMetrics.hotKeyFontSize)).foregroundStyle(.red)
                }
            }
        }
        .onAppear {
            if !model.hotKeyRegistered { warning = SettingsText.hotKeyInUse }
        }
        .onDisappear(perform: stopRecording)
    }

    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        warning = nil
        isRecording = true
        model.suspendHotKey()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            MainActor.assumeIsolated {
                record(event)
            }
            return nil
        }
    }

    private func stopRecording() {
        if isRecording { model.resumeHotKey() }
        isRecording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func record(_ event: NSEvent) {
        guard isRecording else { return }
        if event.keyCode == UInt16(kVK_Escape) {
            stopRecording()
            return
        }
        guard let key = event.charactersIgnoringModifiers?.uppercased(), !key.isEmpty else { return }
        let combo = HotKeyCombo(keyCode: UInt32(event.keyCode), key: key, modifiers: modifiers(of: event))
        guard combo.isValid else {
            warning = SettingsText.hotKeyNeedsModifier
            return
        }
        stopRecording()
        apply(combo)
    }

    private func apply(_ combo: HotKeyCombo) {
        warning = model.setHotKey(combo) ? nil : SettingsText.hotKeyInUse
    }

    private func modifiers(of event: NSEvent) -> Set<HotKeyModifier> {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: Set<HotKeyModifier> = []
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.command) { modifiers.insert(.command) }
        return modifiers
    }
}
