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

struct HotkeyHintLabel: View {
    enum Tone {
        case standard
        case inverted
    }

    let shortcut: String
    var tone: Tone = .standard

    var body: some View {
        Text(HotkeyHintFormatter.hint(from: shortcut))
            .font(.caption2.monospacedDigit().weight(.semibold))
            .foregroundStyle(tone == .inverted ? Color.white.opacity(0.92) : Color.secondary)
    }
}
