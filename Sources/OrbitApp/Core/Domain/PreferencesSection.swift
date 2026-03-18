//
//  PreferencesSection.swift
//  Orbit
//
//  Created by Skye Miller on 3/18/26.
//

import Foundation

public enum PreferencesSection: String, CaseIterable, Identifiable {
    case categories = "Categories"
    case hotkeys = "Hotkeys"
    case appearance = "Appearance"
    case about = "About"
    case credits = "Credits"

    public var id: Self { self }

    var title: String { rawValue }

    var subtitle: String {
        switch self {
        case .categories:
            return "Organize quick capture and session notes with reusable category labels."
        case .hotkeys:
            return "Configure the global shortcuts Orbit registers with macOS."
        case .appearance:
            return "Choose the typography and background treatment Orbit uses across the app."
        case .about:
            return "Versioning, identifiers, and the product-level details for this build."
        case .credits:
            return "Browse the open-source packages bundled into the current Orbit build."
        }
    }

    var symbolName: String {
        switch self {
        case .categories:
            return "square.grid.2x2"
        case .hotkeys:
            return "command"
        case .appearance:
            return "paintpalette"
        case .about:
            return "info.circle"
        case .credits:
            return "shippingbox"
        }
    }
}
