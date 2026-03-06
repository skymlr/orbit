# History Search Panel Override

## Intent

This panel is a calm auxiliary archive browser for the Session workspace. It should feel read-only, precise, and clearly separate from the faster quick-capture surface.

## Rules

- Use the Orbit master background and token palette with `thinMaterial` as the primary panel surface treatment.
- Keep the outer panel geometry at the shared `14pt` panel radius and inner grouped surfaces at `12pt`.
- The toolbar search field is the primary input. Do not add a duplicate in-content search field.
- Day headers carry the main organizational emphasis. Session headers and metadata stay quieter.
- `Go to Day` and `Go to Session` actions can use restrained cyan emphasis, but the panel should not feel as energized as live-session UI.
- Reuse `HistoryTaskRowView` for task results so the panel stays visually aligned with the regular history browser.

## Avoid

- Do not reuse quick-capture’s borderless or transient visual treatment.
- Do not add analytics widgets, heatmaps, or dashboard chrome to the archive search surface.
- Do not overload the panel with extra filters beyond `All / Completed / Open` in this pass.
