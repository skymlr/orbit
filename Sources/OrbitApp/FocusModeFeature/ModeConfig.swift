import SwiftUI

struct ModeConfig: Equatable, Sendable {
    enum Density: Equatable, Sendable {
        case compact
        case regular
        case expanded
    }

    var displayName: String
    var symbolName: String
    var tint: Color
    var capturePlaceholder: String
    var density: Density
}

extension FocusMode {
    var config: ModeConfig {
        switch self {
        case .coding:
            return ModeConfig(
                displayName: "Coding",
                symbolName: "hammer.fill",
                tint: .blue,
                capturePlaceholder: "@todo test cache invalidation edge case",
                density: .compact
            )

        case .researching:
            return ModeConfig(
                displayName: "Researching",
                symbolName: "magnifyingglass",
                tint: .green,
                capturePlaceholder: "@link https://...",
                density: .regular
            )

        case .email:
            return ModeConfig(
                displayName: "Email",
                symbolName: "envelope.fill",
                tint: .orange,
                capturePlaceholder: "@next reply to security review thread",
                density: .compact
            )

        case .meeting:
            return ModeConfig(
                displayName: "Meeting",
                symbolName: "person.3.fill",
                tint: .red,
                capturePlaceholder: "@note decision: adopt staged rollout",
                density: .expanded
            )
        }
    }
}
