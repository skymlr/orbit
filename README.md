# Orbit

Orbit is a focus manager for people who work in deliberate, deep-work sessions and need a clean way to keep track of the tasks that move through those sessions.

The core idea is simple: you start a focus session, capture and organize the work you intend to do, and let unfinished tasks roll forward into the next session until they are completed. Orbit is meant to preserve continuity across sessions so you do not have to rebuild context every time you sit down to work.

## What Orbit Is For

Orbit is useful if you:
- Work in named blocks of focused time instead of an always-on task list.
- Need to capture tasks quickly while staying in flow.
- Want unfinished work to persist automatically into the next session.
- Organize work with priorities and categories.
- Review how a day or week of focused sessions actually unfolded.

## Product Direction

Orbit is currently a macOS-first app, with the Mac experience serving as the primary home for starting sessions, managing live work, quick capture, and reviewing history.

The iOS app is intended to extend that experience so your sessions and tasks are available from your phone as well as your Mac. The longer-term direction is a cross-device workflow where Orbit feels like one system rather than separate apps.

An upcoming feature is iCloud sync to support cross-device sharing and continuity between macOS and iOS. Until that lands, local persistence remains the source of truth.

## Current Capabilities

- Full macOS app with Dock presence and menu bar extra (`circle` / `circle.fill` status icon).
- Start a new session or reopen the active one from the menu bar or a global hotkey.
- Floating Quick Capture panel for fast task entry without breaking focus.
- Markdown task editing with rendered markdown display.
- Task priorities: `none`, `low`, `medium`, `high`.
- Multiple user-defined categories per task.
- Automatic carry-over of unfinished tasks from the most recently ended session.
- Session history with rename, delete, and markdown export support.
- Preferences for categories, hotkeys, and app credits.
- Auto-end behavior for inactivity and app termination.

## Typical Workflow

1. Start a session when you begin a deep-work block.
2. Add tasks as they come up through the workspace or Quick Capture.
3. Mark tasks complete as you finish them.
4. End the session when the block is over.
5. Resume later with unfinished tasks already carried into the next session.

## Default Hotkeys

- Start/Open session: `ctrl+option+cmd+k`
- Quick capture: `ctrl+option+cmd+j`

Both are configurable in Preferences and can be reset to defaults.

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

- [Sources/OrbitApp/App](Sources/OrbitApp/App): App entry points, lifecycle coordinators, and the root reducer.
- [Sources/OrbitApp/Features](Sources/OrbitApp/Features): Product features including menu bar, quick capture, preferences, session workspace, and history.
- [Sources/OrbitApp/Core](Sources/OrbitApp/Core): Shared domain models, markdown behavior, and reusable UI primitives.
- [Sources/OrbitApp/Infrastructure](Sources/OrbitApp/Infrastructure): Persistence, repositories, and dependency clients.
- [Resources/Assets.xcassets](Resources/Assets.xcassets): App icon and asset catalog.
- [Tests/OrbitAppTests](Tests/OrbitAppTests): Tests covering reducers, markdown, history, preferences, and persistence.

## Data Storage

Orbit currently stores data in a local SQLite database at:
- `~/Library/Application Support/Orbit/focus.sqlite`

This includes sessions, tasks, categories, task-category links, priorities, and completion metadata.
