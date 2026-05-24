# Lakshya

A graph-based personal goal and task manager. Sanskrit for "goal" or "target".

## Concept

Every item is a node in a directed acyclic graph. The root node is "all goals achieved". Each new node is added as either *mandatory* or *helpful* for at least one existing parent goal. A node can have multiple parents, so the same task can contribute to several higher goals at once. The default view shows the leaves of the current filter, since leaves are the actionable items.

Each node has one status type:

- **Always-on**: no completion state, used for top-level goals like "Health" or "Work".
- **One-time**: completed once and done.
- **N-times**: counts down a fixed number of completions.
- **Periodic**: re-opens a fixed number of days after the last completion, not on a fixed clock. Completing a "gym every 3 days" task on day 5 schedules the next one for day 8, not day 6.
- **Temporarily active**: bounded by a start and end date.

Nodes can carry priority, deadlines, attachments (URL, geo location, time trigger), and notification settings. Manual priority pins ("this node beats this one") override the default ordering.

Two main views:

1. Graph view with text and attribute filters (by ancestor goal, by mandatory vs helpful, by status, by free-text search), and a leaf-only toggle.
2. Dashboard tiles, where each tile is a saved filter preset such as Work, Leisure, or Outstanding. Tap a tile to open the graph view pre-filtered.

When any UI flow asks the user to pick a node (for adding a new parent, a dependency, a relationship), the picker shows the whole graph with the same filter controls.

## Tech stack

- Flutter and Dart for the UI. One codebase for web, iOS, Android, and macOS desktop.
- Local-only storage. The graph is persisted as a single pretty-printed JSON file in the app data directory.
- Hand-written, sealed-class data model in `lib/model/`. The JSON Schema in `schema/lakshya.schema.json` is the documented source of truth for the wire format and is used for runtime validation of on-disk data; it does not generate code.
- No backend. The repository layer is designed behind an interface (`GraphRepository`) so cloud sync can be added later without touching the rest of the app.

## Architecture and quality principles

These rules apply to every change in this repo:

1. **Test-driven development.** Write the failing test first. Then write the smallest production code that makes it pass. Then refactor. This applies to model logic, the graph engine, the repository, and widgets (via `flutter_test`).
2. **Layered architecture.** `model`, `repository`, `service` (graph engine, recurrence resolver, filters), `view`, `widgets`, `theme`. Higher layers depend on lower layers, never the reverse.
3. **Readable names over short names.** Prefer `recurrenceIntervalSinceLastCompletion` over `recur`, and `findLeavesUnder(goal)` over `f(g)`. No cryptic abbreviations.
4. **Dependency injection over globals.** Services and repositories are passed in, not reached for.
5. **Small, single-purpose functions.** If a function needs a paragraph to explain, split it.
6. **Schema-first data model.** Data shape changes start in `schema/lakshya.schema.json` (documentation + runtime validation), and are then reflected by hand in the corresponding Dart classes in `lib/model/` with matching tests.

## Build phases

0. **Setup.** Install Flutter, run `flutter create`, init git, lay out the base directory structure.
1. **Data model.** Write the JSON Schema as the documented wire format, hand-write matching Dart classes (sealed unions for `NodeStatus` and `Attachment`), build the repository and JSON file persistence, and run loaded JSON through schema validation. All with TDD.
2. **Graph engine.** DAG traversal with multi-parent support, leaf detection, filter predicates, recurrence resolver, default ordering with manual priority overrides, computed "ongoing tasks" view.
3. **Default view.** Graph canvas with pan, zoom, and animated transitions. Filter sidebar. Node inspector. Add and edit modal with a full-graph node picker for parent and dependency selection.
4. **Dashboard tiles.** A launcher screen of large tiles, one per saved filter preset. Tap to enter the graph view pre-filtered. Add, edit, reorder presets.
5. **Reminders and attachments.** Local notifications based on a global lead time before deadlines, re-open notifications for periodic tasks, URL and geo and time-trigger attachments, OS permission handling.
6. **Export / import.** "Export to JSON" button (writes the current graph to a user-chosen file) and "Import from JSON" button (reads a user-chosen file and runs it through `SchemaValidator.validateOrThrow` before replacing the in-memory graph). Imports must surface validation errors clearly in the UI rather than silently dropping fields.
7. **Polish.** Shiva-themed color palette, SVG logo (trident or yantra geometry), PWA manifest and service worker for install-to-home-screen, responsive breakpoints for phone, tablet, and desktop.
8. **Deferred.** Optional multi-device sync via cloud folder or a minimal backend. Not in scope for the initial build.

## Repository layout

```
lakshya/
  schema/
    lakshya.schema.json     # documented wire format, used for runtime validation
  lib/
    model/                  # hand-written sealed-class data model
    repository/             # GraphRepository interface + LocalJsonRepository
    service/                # graph engine, recurrence, filters, schema validation
    view/                   # top-level screens (graph view, dashboard, settings)
    widgets/                # reusable widgets (node picker, filter sidebar, etc.)
    theme/                  # colors, typography, animations
  test/
    model/
    repository/
    service/
    widget/
  assets/                   # logo, icons, fonts
```

## Development setup

Once Flutter is installed:

```
flutter pub get
flutter test                 # run all tests
flutter run -d chrome        # web build
flutter run -d macos         # desktop build
flutter run -d <device-id>   # iOS or Android (after `flutter devices`)
```

To change the data model:

1. Update `schema/lakshya.schema.json` first (the documented wire format and the runtime validator's source of truth).
2. Reflect the change by hand in the matching class under `lib/model/`, keeping naming idiomatic (`mandatory`, not `MANDATORY`; `Node`, not `NodeElement`).
3. Update or add tests under `test/model/` covering both `fromJson`/`toJson` and any new variant logic.
4. Run `flutter analyze` and `flutter test`.

## Status

Project started 2026-05-24. Phase 0 in progress.
