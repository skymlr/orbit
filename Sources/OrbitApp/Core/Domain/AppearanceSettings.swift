import Foundation

enum OrbitFontOption: String, CaseIterable, Codable, Equatable, Sendable, Identifiable {
    case system
    case geist
    case robotoMonoNerd
    case sourceSerif4

    var id: Self { self }

    var title: String {
        switch self {
        case .system:
            return "System Default"
        case .geist:
            return "Geist"
        case .robotoMonoNerd:
            return "Roboto Mono Nerd"
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
        case .robotoMonoNerd:
            return "Roboto Mono Nerd Mono"
        case .sourceSerif4:
            return "Source Serif 4"
        }
    }
}

enum OrbitBackgroundOption: String, CaseIterable, Codable, Equatable, Sendable, Identifiable {
    case spaceBlue = "orbit"
    case skyBlue = "blue"
    case purple
    case glass

    var id: Self { self }

    var title: String {
        switch self {
        case .spaceBlue:
            return "Space Blue"
        case .skyBlue:
            return "Sky Blue"
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
    var showsOrbitalLayer: Bool

    static let `default` = AppearanceSettings(
        font: .system,
        background: .spaceBlue,
        showsOrbitalLayer: true
    )
}
