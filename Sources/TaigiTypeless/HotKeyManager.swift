import Carbon
import Foundation

enum HotKeyError: Error {
    case registrationFailed(OSStatus)
    case handlerFailed(OSStatus)
}

final class HotKeyManager: @unchecked Sendable {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var callback: (@Sendable () -> Void)?
    private let signature = fourCharCode("TGTY")
    private let hotKeyID = UInt32(1)

    func registerOptionSpace(callback: @escaping @Sendable () -> Void) throws {
        self.callback = callback

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var incomingID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &incomingID
                )
                guard status == noErr else { return status }

                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                guard incomingID.signature == manager.signature, incomingID.id == manager.hotKeyID else {
                    return noErr
                }
                DispatchQueue.main.async {
                    manager.callback?()
                }
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            &eventHandlerRef
        )
        guard handlerStatus == noErr else { throw HotKeyError.handlerFailed(handlerStatus) }

        let carbonHotKeyID = EventHotKeyID(signature: signature, id: hotKeyID)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(optionKey),
            carbonHotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else { throw HotKeyError.registrationFailed(registerStatus) }
    }

    deinit {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }
}

private func fourCharCode(_ string: String) -> OSType {
    string.utf8.reduce(0) { partial, byte in
        (partial << 8) + OSType(byte)
    }
}
