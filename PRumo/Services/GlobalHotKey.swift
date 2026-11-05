import Carbon.HIToolbox
import PRumoKit

@MainActor
final class GlobalHotKey {
    private let onPress: @MainActor () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    init(onPress: @escaping @MainActor () -> Void) {
        self.onPress = onPress
    }

    isolated deinit {
        unregister()
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }

    func register(_ combo: HotKeyCombo) -> Bool {
        guard installHandlerIfNeeded() else { return false }
        unregister()
        var reference: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: AppConstants.hotKeySignature, id: AppConstants.hotKeyID)
        let status = RegisterEventHotKey(
            combo.keyCode, combo.carbonModifiers, identifier, GetApplicationEventTarget(),
            OptionBits(kEventHotKeyExclusive), &reference)
        guard status == noErr, let reference else { return false }
        hotKeyRef = reference
        return true
    }

    func unregister() {
        guard let hotKeyRef else { return }
        UnregisterEventHotKey(hotKeyRef)
        self.hotKeyRef = nil
    }

    private func installHandlerIfNeeded() -> Bool {
        guard handlerRef == nil else { return true }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        var reference: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(), globalHotKeyHandler, 1, &eventType,
            Unmanaged.passUnretained(self).toOpaque(), &reference)
        guard status == noErr else { return false }
        handlerRef = reference
        return true
    }

    fileprivate func handle(_ identifier: EventHotKeyID) {
        guard identifier.signature == AppConstants.hotKeySignature, identifier.id == AppConstants.hotKeyID else { return }
        onPress()
    }
}

private func globalHotKeyHandler(_ next: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event, let userData else { return OSStatus(eventNotHandledErr) }
    var identifier = EventHotKeyID()
    let status = GetEventParameter(
        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
        MemoryLayout<EventHotKeyID>.size, nil, &identifier)
    guard status == noErr else { return status }
    let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
    MainActor.assumeIsolated {
        hotKey.handle(identifier)
    }
    return noErr
}
