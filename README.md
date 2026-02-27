# Orbit: A Focus Manager

Orbit is a menu bar-first macOS focus companion built with SwiftUI, TCA, and SQLite.

## Highlights
- Menu bar app (`LSUIElement`) with `circle` / `circle.fill` status icon.
- Start/open active session from menu or global hotkey.
- Floating Quick Capture panel for fast note entry.
- Notes support markdown source editing and attributed markdown rendering.
- Note metadata includes tags and priority (`none`, `low`, `medium`, `high`).
- Session categories with user-defined colors.
- Session management in Settings (rename, delete, export markdown).
- Auto-end behavior:
  - 8 hours of inactivity.
  - App termination.

## Default Hotkeys
- Start/Open session: `ctrl+option+cmd+k`
- Quick capture: `ctrl+option+cmd+j`

Both are configurable in Settings, and can be reset to defaults.

## Tech Stack
- SwiftUI
- The Composable Architecture
- Point-Free Dependencies
- SQLiteData + StructuredQueries
- Swift Navigation / Case Paths

## Running The App
### Xcode (recommended)
1. Open [Orbit.xcodeproj](Orbit.xcodeproj).
2. Select the `Orbit` scheme.
3. Build and run.

### CLI build
```bash
xcodebuild -project Orbit.xcodeproj -scheme Orbit -configuration Debug -destination 'platform=macOS' build
```

## Tests
```bash
swift test
```

## Project Layout
- [Sources/OrbitApp](Sources/OrbitApp): App features, dependencies, shared UI components.
- [Resources/Assets.xcassets](Resources/Assets.xcassets): App icon and asset catalog.
- [Tests/OrbitAppTests](Tests/OrbitAppTests): Reducer and markdown editing tests.
- [Scripts/generate_xcodeproj.rb](Scripts/generate_xcodeproj.rb): Regenerates the native Xcode project.

## Data Storage
Orbit stores data in a local SQLite database at:
- `~/Library/Application Support/Orbit/focus.sqlite`

This includes sessions, categories, notes, tags, and note priorities.
