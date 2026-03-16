import SwiftUI

enum HotkeyHintFormatter {
    static func hint(from shortcut: String) -> String {
        let components = shortcut
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        guard let keyPart = components.last, !keyPart.isEmpty else {
            return shortcut.uppercased()
        }

        let modifiers = Set(components.dropLast())
        let control = modifiers.contains("ctrl") || modifiers.contains("control")
        let option = modifiers.contains("option") || modifiers.contains("opt") || modifiers.contains("alt")
        let shift = modifiers.contains("shift")
        let command = modifiers.contains("cmd") || modifiers.contains("command")

        var glyphs = ""
        if control { glyphs += "⌃" }
        if option { glyphs += "⌥" }
        if shift { glyphs += "⇧" }
        if command { glyphs += "⌘" }

        return glyphs + keyGlyph(for: String(keyPart))
    }

    static func keyGlyph(for key: String) -> String {
        switch key.lowercased() {
        case "space":
            return "Space"
        case "return", "enter":
            return "↩"
        case "tab":
            return "⇥"
        case "escape", "esc":
            return "⎋"
        case "delete", "backspace":
            return "⌫"
        case "up":
            return "↑"
        case "down":
            return "↓"
        case "left":
            return "←"
        case "right":
            return "→"
        default:
            return key.uppercased()
        }
    }
}

struct OrbitKeyboardShortcut {
    var key: KeyEquivalent
    var modifiers: EventModifiers
}

enum OrbitKeyboardShortcutParser {
    static func parse(_ shortcut: String) -> OrbitKeyboardShortcut? {
        let components = shortcut
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        guard let keyPart = components.last, !keyPart.isEmpty else {
            return nil
        }

        var modifiers: EventModifiers = []
        for modifier in components.dropLast() {
            switch modifier {
            case "ctrl", "control":
                modifiers.insert(.control)
            case "option", "opt", "alt":
                modifiers.insert(.option)
            case "shift":
                modifiers.insert(.shift)
            case "cmd", "command":
                modifiers.insert(.command)
            default:
                continue
            }
        }

        guard let key = keyEquivalent(for: String(keyPart)) else {
            return nil
        }

        return OrbitKeyboardShortcut(key: key, modifiers: modifiers)
    }

    private static func keyEquivalent(for key: String) -> KeyEquivalent? {
        switch key.lowercased() {
        case "space":
            return .space
        case "return", "enter":
            return .return
        case "tab":
            return .tab
        case "escape", "esc":
            return .escape
        case "up":
            return .upArrow
        case "down":
            return .downArrow
        case "left":
            return .leftArrow
        case "right":
            return .rightArrow
        default:
            guard key.count == 1, let scalar = key.unicodeScalars.first else {
                return nil
            }
            return KeyEquivalent(Character(scalar))
        }
    }
}

extension View {
    @ViewBuilder
    func orbitKeyboardShortcut(_ shortcut: String) -> some View {
        if let parsed = OrbitKeyboardShortcutParser.parse(shortcut) {
            self.keyboardShortcut(parsed.key, modifiers: parsed.modifiers)
        } else {
            self
        }
    }
}

struct HotkeyHintLabel: View {
    enum Tone {
        case standard
        case inverted
    }

    let shortcut: String
    var tone: Tone = .standard

    var body: some View {
        Text(HotkeyHintFormatter.hint(from: shortcut))
            .orbitFont(.caption2, weight: .semibold, monospacedDigits: true)
            .foregroundStyle(tone == .inverted ? Color.white.opacity(0.92) : Color.secondary)
    }
}
