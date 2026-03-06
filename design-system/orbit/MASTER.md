# Orbit Design System Master

> Check `design-system/orbit/pages/[page-name].md` first. If a page file exists, it overrides this master.

## Product Character

Orbit is a quiet space-console for focused work on macOS.

- The mood is observatory, not arcade.
- The UI should feel luminous and calm, not loud or cyberpunk.
- Motion should suggest orbital drift and instrument feedback, not bounce-heavy playfulness.
- The visual metaphor is solar system geometry over frosted glass.

## Source Of Truth

- Code tokens live in `Sources/OrbitApp/Shared/OrbitDesignSystem.swift`.
- Shared background, buttons, toast, and task-card primitives should pull from those tokens instead of redefining raw colors.
- SF Symbols are the icon system. Do not introduce emoji or mixed icon sets.

## Core Palette

| Token | Hex | Use |
|------|-----|-----|
| `spaceTop` | `#0A1729` | Upper canvas |
| `spaceBottom` | `#0F243D` | Lower canvas |
| `nebula` | `#336B8F` | Atmospheric glow |
| `orbitLine` | `#94D6F2` | Strokes, active outlines, orbit paths |
| `starlight` | `#B8EDFF` | Highlights and cool glow |
| `heroNavy` | `#05243D` | Dark surfaces and task overlays |
| `heroCyan` | `#054A66` | Primary action depth |
| `heroAmber` | `#3D300A` | Warm counterweight in hero gradients |
| `sunHalo` | `#FFD475` | Warm atmospheric glow |
| `sunFlare` | `#F5A142` | Accent flare, hero strokes |
| `sunCore` | `#FFEDB2` | Bright solar center |
| `sunCoreEdge` | `#FFBD63` | Inner solar edge |
| `priorityNone` | `#9EB2D6` | Neutral priority |
| `priorityLow` | `#14DBC7` | Low priority |
| `priorityMedium` | `#FFBD2E` | Medium priority |
| `priorityHigh` | `#FF458A` | High priority |
| `completionGreen` | `#5CDB75` | Completion success |
| `toastSuccess` | `#61D999` | Positive notification |
| `toastFailure` | `#FA736B` | Failure / destructive feedback |
| `lightPanel` | `#E6F2FC` | Light-mode secondary fills |
| `lightPanelSoft` | `#EBF5FF` | Light-mode quiet fills |
| `lightText` | `#0D3352` | Light-mode primary text on pale panels |
| `lightTextSecondary` | `#1A4C6E` | Light-mode quiet labels |
| `lightStroke` | `#146E9E` | Light-mode borders |
| `lightStrokeSoft` | `#1C75A6` | Light-mode quiet borders |

## Material And Surface Rules

- The app canvas is always the space gradient plus star field plus lower-right solar motif.
- Primary surfaces use `ultraThinMaterial` over the cosmic background.
- Secondary read-only or fallback surfaces use `thinMaterial`.
- Dark glass opacity should stay in the `0.32` to `0.44` range for main chrome.
- White glass borders are subtle: default `0.14`, strong `0.20`.
- Cyan borders indicate active selection or page focus, not generic decoration.

## Typography

- Use the native macOS system stack: SF Pro Display and SF Pro Text through SwiftUI system fonts.
- Large moments use bold system titles, not novelty sci-fi fonts.
- Shortcuts, timers, and counts use monospaced digits.
- Caption and caption2 are the default metadata layers.
- Headlines should stay sentence case. Do not switch the interface to all-caps HUD styling.

### Type Roles

| Role | SwiftUI pattern | Use |
|------|-----------------|-----|
| Hero action | `.title3.weight(.bold)` | Menu/session launch moments |
| Page title | `.largeTitle.weight(.bold)` | Active session header |
| Section title | `.title3.weight(.semibold)` | History blocks, empty states |
| Standard action | `.callout.weight(.semibold)` | Buttons |
| Body | `.body` | Task content |
| Metadata | `.caption`, `.caption2` | Time, counts, labels |
| Shortcut text | `.caption.monospacedDigit().weight(.semibold)` | Keyboard hints |

## Geometry

| Token | Value | Use |
|------|-------|-----|
| `6` | Day chips | Calendar cells |
| `8` | Editor wells | Inline editors, selected rows |
| `10` | Strip cards | Session pills, menus |
| `12` | Standard cards | Task rows, toasts, read-only blocks |
| `14` | Main panels | Menu bar popover, quick capture shell |
| `16` | Standard buttons | Primary and secondary controls |
| `22` | Hero actions | Start-session CTA |

## Spacing And Layout

- Primary spacing rhythm: `4, 6, 8, 10, 12, 14, 18, 20`.
- Main content width for workspace detail sections: `700pt`.
- Session workspace minimum frame: `880 x 640`.
- Menu bar surface width: `360pt`.
- Dense utility clusters should sit in `6-10pt` spacing; section blocks should sit in `14-20pt`.

## Motion

| Token | Value | Use |
|------|-------|-----|
| `press` | `120ms` | Button press response |
| `hover` | `140ms` | Lift and shadow on hover |
| `micro` | `160ms` | Panel swaps, preview toggles |
| `standard` | `180ms` | State transitions |
| `relaxed` | `240ms` | Toast and cross-surface changes |
| `celebration` | `540ms` | Task completion burst only |

- Hover motion lifts upward by `1-2pt`.
- Hover glow is cyan-tinted by default.
- Reduced motion must flatten hover lift and disable unnecessary animation where possible.
- Celebration motion is reserved for task completion. Do not spread it to ordinary controls.

## Component Rules

### Background

- Use the shared orbital background everywhere a primary Orbit surface appears.
- The lower-right solar motif is brand-defining and should remain visible behind translucent chrome.
- Do not place opaque full-bleed cards over the entire background.

### Buttons

- Hero buttons use the navy to cyan to amber gradient with a `22pt` radius and orbit/flare stroke.
- Primary buttons use navy to cyan gradient fills and white text.
- Secondary buttons are glass ghost buttons that adapt for dark and light modes.
- Quiet buttons are small capsule utilities for filter toggles and preview controls.
- Destructive buttons use restrained red glass; they should read as dangerous without overpowering the surface.

### Chips

- Category chips are capsules with tinted fill at roughly `28%` and a crisp `1pt` stroke.
- Counts live in darker nested capsules.
- Filter chips should use the category tint or priority tint directly.

### Task Cards

- Task cards are `12pt` glass cards with a dark navy overlay, a left priority rail, and optional completion animation.
- Completion control uses concentric orbit rings and a short celebratory particle burst.
- Completed tasks reduce text opacity instead of disappearing into the background.

### Notifications

- Toasts use `12pt` glass cards with tone-colored icon and border.
- Success is green. Failure is coral-red. No extra neutral toast palette is needed unless a new state appears.

## Accessibility

- All interactive surfaces need clear hover feedback and visible focus states.
- Keyboard shortcuts are first-class UI and should be exposed anywhere a shortcut materially speeds the workflow.
- Cyan and amber are accent colors, not the sole source of meaning. Keep icon, label, or structural reinforcement.
- Maintain readable light-mode text on pale glass surfaces.

## Anti-Patterns

- No purple-first palette. The system is blue, cyan, amber, and restrained coral.
- No solid black panels or pure white slabs over the orbital background.
- No thick borders above `1.3pt` unless the component is intentionally selected.
- No generic neon glow on everything. Glow is sparse and purposeful.
- No playful bounce on ordinary buttons, menus, or chips.
- No mixed visual metaphors such as skeuomorphic hardware, retro terminal green, or game UI chrome.

## Build Checklist

- [ ] New UI tokens come from `OrbitDesignSystem.swift` before adding raw literals.
- [ ] Primary surfaces preserve the space background and glass layering.
- [ ] Interactive controls keep the existing hover-lift language.
- [ ] Reduced motion is respected for new motion-heavy components.
- [ ] SF Symbols remain the icon system.
- [ ] Light-mode surfaces use `lightPanel` and `lightStroke` families instead of washed-out white.
- [ ] Priority, completion, and destructive states use their reserved accent colors only.
