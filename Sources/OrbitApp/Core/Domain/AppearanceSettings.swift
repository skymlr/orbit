import Foundation

enum OrbitFontOption: String, CaseIterable, Codable, Equatable, Sendable, Identifiable {
    case system
    case geist
    case sourceSerif4

    var id: Self { self }

    var title: String {
        switch self {
        case .system:
            return "System Default"
        case .geist:
            return "Geist"
        case .sourceSerif4:
            return "Source Serif 4"
        }
    }

    var previewName: String {
        switch self {
        case .system:
            return "Current Orbit default"
        case .geist:
            return "Geist"
        case .sourceSerif4:
            return "Source Serif 4"
        }
    }
}

enum OrbitBackgroundOption: String, CaseIterable, Codable, Equatable, Sendable, Identifiable {
    case orbit
    case blue
    case purple
    case glass

    var id: Self { self }

    var title: String {
        switch self {
        case .orbit:
            return "Orbit Default"
        case .blue:
            return "Blue"
        case .purple:
            return "Purple"
        case .glass:
            return "Glass"
        }
    }
}

struct AppearanceSettings: Equatable, Sendable {
    var font: OrbitFontOption
    var background: OrbitBackgroundOption

    static let `default` = AppearanceSettings(
        font: .system,
        background: .orbit
    )
}
