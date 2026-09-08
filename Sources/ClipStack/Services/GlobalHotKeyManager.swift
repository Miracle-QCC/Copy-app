import Carbon
import Foundation

@MainActor
final class GlobalHotKeyManager {
    private let signature: OSType = 0x434C4950
    private let identifier: UInt32 = 1
    private let action: () -> Void
    private var hotKeyReference: EventHotKeyRef?
    private var eventHandlerReference: EventHandlerRef?

    init(action: @escaping () -> Void) {
        self.action = action
    }

    @discardableResult
    func registerControlV() -> Bool {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else {
                    return OSStatus(eventNotHandledErr)
                }

                var hotKeyID = EventHotKeyID()
                let parameterStatus = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard parameterStatus == noErr else {
                    return parameterStatus
                }

                let manager = Unmanaged<GlobalHotKeyManager>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                return MainActor.assumeIsolated {
                    guard hotKeyID.signature == manager.signature,
                          hotKeyID.id == manager.identifier else {
                        return OSStatus(eventNotHandledErr)
                    }
                    manager.action()
                    return noErr
                }
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerReference
        )

        guard handlerStatus == noErr else {
            return false
        }

        let hotKeyID = EventHotKeyID(signature: signature, id: identifier)
        var registrationStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(controlKey),
            hotKeyID,
            GetApplicationEventTarget(),
            OptionBits(kEventHotKeyExclusive),
            &hotKeyReference
        )

        // Another process may already have an exclusive registration. Falling
        // back keeps ClipStack usable instead of disabling the shortcut
        // completely; Carbon can deliver non-exclusive registrations to more
        // than one application.
        if registrationStatus == eventHotKeyExistsErr {
            registrationStatus = RegisterEventHotKey(
                UInt32(kVK_ANSI_V),
                UInt32(controlKey),
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyReference
            )
        }

        if registrationStatus != noErr {
            unregister()
            return false
        }
        return true
    }

    func unregister() {
        if let hotKeyReference {
            UnregisterEventHotKey(hotKeyReference)
            self.hotKeyReference = nil
        }
        if let eventHandlerReference {
            RemoveEventHandler(eventHandlerReference)
            self.eventHandlerReference = nil
        }
    }
}
