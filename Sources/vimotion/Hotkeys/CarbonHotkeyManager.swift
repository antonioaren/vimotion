import Carbon.HIToolbox
import Foundation

/// Registers global hotkeys with Carbon's `RegisterEventHotKey`. Reliable for
/// fixed modifier+key combinations and requires no extra entitlements.
public final class CarbonHotkeyManager: HotkeyManaging {

    public var onDirection: ((Direction) -> Void)?
    public private(set) var isActive: Bool = false

    /// Four-char signature identifying our hotkeys.
    private let signature: OSType = 0x766D_6F74 // "vmot"

    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?
    /// Maps a registered hotkey id to its direction.
    private var directionByID: [UInt32: Direction] = [:]

    public init() {}

    deinit {
        unregister()
        removeEventHandler()
    }

    public func register(leader: LeaderKey) {
        // Always start from a clean slate so leader changes take effect.
        unregister()
        installEventHandlerIfNeeded()

        for (index, shortcut) in Shortcut.navigation.enumerated() {
            let id = UInt32(index)
            var hotKeyID = EventHotKeyID(signature: signature, id: id)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                shortcut.keyCode,
                leader.carbonModifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &ref
            )
            if status == noErr, let ref {
                hotKeyRefs.append(ref)
                directionByID[id] = shortcut.direction
            } else {
                Log.error("Failed to register hotkey for \(shortcut.direction) (status \(status))")
            }
            _ = hotKeyID // silence unused warning on some toolchains
        }

        isActive = !hotKeyRefs.isEmpty
        Log.info("Hotkeys registered with leader \(leader.rawValue): active=\(isActive)")
    }

    public func unregister() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        directionByID.removeAll()
        isActive = false
    }

    // MARK: - Event handler

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<CarbonHotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                return manager.handle(event: event)
            },
            1,
            &eventType,
            selfPtr,
            &eventHandler
        )
    }

    private func removeEventHandler() {
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }

    private func handle(event: EventRef) -> OSStatus {
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr,
              hotKeyID.signature == signature,
              let direction = directionByID[hotKeyID.id] else {
            return OSStatus(eventNotHandledErr)
        }

        // Hop to the main thread for AppKit-touching work.
        DispatchQueue.main.async { [weak self] in
            self?.onDirection?(direction)
        }
        return noErr
    }
}
