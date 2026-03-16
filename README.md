# Orbit: A Focus Manager

Orbit is a macOS focus companion built with SwiftUI, TCA, and SQLite.

## Highlights
- Full macOS app with Dock icon and menu bar extra (`circle` / `circle.fill` status icon).
- Start/open active session from menu or global hotkey.
- Floating Quick Capture panel for fast task entry.
- Tasks support markdown source editing and attributed markdown rendering.
- Task metadata includes priority (`none`, `low`, `medium`, `high`).
- Tasks support multiple user-defined categories.
- Task-level completion with carry-over from the most recently ended session.
- Session history management (rename, delete, and export markdown).
- Dedicated Preferences window for categories, hotkeys, and app credits.
- Auto-end behavior:
  - 8 hours of inactivity.
  - App termination.

## Default Hotkeys
- Start/Open session: `ctrl+option+cmd+k`
- Quick capture: `ctrl+option+cmd+j`

Both are configurable in Preferences, and can be reset to defaults.

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
- [Sources/OrbitApp/App](Sources/OrbitApp/App): App entrypoints, lifecycle coordinators, and the root reducer.
- [Sources/OrbitApp/Features](Sources/OrbitApp/Features): Feature folders for menu bar, quick capture, preferences, and workspace flows.
- [Sources/OrbitApp/Core](Sources/OrbitApp/Core): Shared domain models, markdown logic, and reusable UI primitives.
- [Sources/OrbitApp/Infrastructure](Sources/OrbitApp/Infrastructure): Dependencies, persistence, and repository implementations.
- [Resources/Assets.xcassets](Resources/Assets.xcassets): App icon and asset catalog.
- [Tests/OrbitAppTests](Tests/OrbitAppTests): Tests mirrored to the app structure for reducers, markdown, history, preferences, and persistence.

## Data Storage
Orbit stores data in a local SQLite database at:
- `~/Library/Application Support/Orbit/focus.sqlite`

This includes sessions, categories, tasks, task-category links, priorities, and completion metadata.
