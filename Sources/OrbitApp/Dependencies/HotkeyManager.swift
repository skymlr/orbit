import Carbon
import Dependencies
import Foundation

struct HotkeyManager: Sendable {
    var register: @Sendable (_ shortcut: String, _ action: @escaping @Sendable () -> Void) -> Void
    var unregister: @Sendable (_ shortcut: String) -> Void
}

extension HotkeyManager: DependencyKey {
    static var liveValue: HotkeyManager {
        HotkeyManager(
            register: { shortcut, action in
                HotkeyCenter.shared.register(shortcut: shortcut, action: action)
            },
            unregister: { shortcut in
                HotkeyCenter.shared.unregister(shortcut: shortcut)
            }
        )
    }

    static var testValue: HotkeyManager {
        HotkeyManager(
            register: { _, _ in },
            unregister: { _ in }
        )
    }
}

extension DependencyValues {
    var hotkeyManager: HotkeyManager {
        get { self[HotkeyManager.self] }
        set { self[HotkeyManager.self] = newValue }
    }
}

private final class HotkeyCenter: @unchecked Sendable {
    static let shared = HotkeyCenter()

    private struct RegisteredHotkey {
        var id: UInt32
        var ref: EventHotKeyRef
        var action: @Sendable () -> Void
    }

    private let lock = NSLock()
    private var shortcuts: [String: RegisteredHotkey] = [:]
    private var actionsByID: [UInt32: (@Sendable () -> Void)] = [:]
    private var nextID: UInt32 = 1
    private var eventHandler: EventHandlerRef?

    private init() {
        installEventHandlerIfNeeded()
    }

    func register(shortcut: String, action: @escaping @Sendable () -> Void) {
        lock.lock()
        defer { lock.unlock() }

        unregisterLocked(shortcut: shortcut)

        guard let parsed = parseShortcut(shortcut) else { return }

        let hotKeyID = EventHotKeyID(signature: hotkeySignature, id: nextID)
        var ref: EventHotKeyRef?

        let status = RegisterEventHotKey(
            UInt32(parsed.keyCode),
            parsed.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        guard status == noErr, let ref else { return }

        let registered = RegisteredHotkey(id: hotKeyID.id, ref: ref, action: action)
        shortcuts[shortcut] = registered
        actionsByID[hotKeyID.id] = action
        nextID += 1
    }

    func unregister(shortcut: String) {
        lock.lock()
        defer { lock.unlock() }
        unregisterLocked(shortcut: shortcut)
    }

    func handle(event: EventRef?) {
        guard let event else { return }

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

        guard status == noErr else { return }

        let action = lock.withLock {
            actionsByID[hotKeyID.id]
        }
        action?()
    }

    private func unregisterLocked(shortcut: String) {
        guard let registered = shortcuts.removeValue(forKey: shortcut) else { return }
        UnregisterEventHotKey(registered.ref)
        actionsByID.removeValue(forKey: registered.id)
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            orbitHotkeyEventHandler,
            1,
            &spec,
            nil,
            &eventHandler
        )
    }

    private func parseShortcut(_ raw: String) -> ParsedShortcut? {
        let lowercased = raw.lowercased()
        let parts = lowercased.split(separator: "+").map(String.init)
        guard let keyPart = parts.last else { return nil }

        let modifiers = parts.dropLast().reduce(UInt32(0)) { partial, token in
            switch token {
            case "cmd", "command":
                return partial | UInt32(cmdKey)
            case "shift":
                return partial | UInt32(shiftKey)
            case "opt", "option", "alt":
                return partial | UInt32(optionKey)
            case "ctrl", "control":
                return partial | UInt32(controlKey)
            default:
                return partial
            }
        }

        guard let keyCode = keyCodeMap[keyPart] else { return nil }
        return ParsedShortcut(keyCode: keyCode, modifiers: modifiers)
    }
}

private struct ParsedShortcut {
    var keyCode: Int
    var modifiers: UInt32
}

private let hotkeySignature: OSType = 0x4F524254

private func orbitHotkeyEventHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    HotkeyCenter.shared.handle(event: event)
    return noErr
}

private let keyCodeMap: [String: Int] = [
    "a": Int(kVK_ANSI_A), "b": Int(kVK_ANSI_B), "c": Int(kVK_ANSI_C), "d": Int(kVK_ANSI_D),
    "e": Int(kVK_ANSI_E), "f": Int(kVK_ANSI_F), "g": Int(kVK_ANSI_G), "h": Int(kVK_ANSI_H),
    "i": Int(kVK_ANSI_I), "j": Int(kVK_ANSI_J), "k": Int(kVK_ANSI_K), "l": Int(kVK_ANSI_L),
    "m": Int(kVK_ANSI_M), "n": Int(kVK_ANSI_N), "o": Int(kVK_ANSI_O), "p": Int(kVK_ANSI_P),
    "q": Int(kVK_ANSI_Q), "r": Int(kVK_ANSI_R), "s": Int(kVK_ANSI_S), "t": Int(kVK_ANSI_T),
    "u": Int(kVK_ANSI_U), "v": Int(kVK_ANSI_V), "w": Int(kVK_ANSI_W), "x": Int(kVK_ANSI_X),
    "y": Int(kVK_ANSI_Y), "z": Int(kVK_ANSI_Z),
]

private extension NSLock {
    func withLock<T>(_ operation: () -> T) -> T {
        lock()
        defer { unlock() }
        return operation()
    }
}
