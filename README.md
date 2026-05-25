# Lakshya

A graph-based personal goal and task manager. Sanskrit for "goal" or "target".

## Concept

Every item is a node in a directed acyclic graph (DAG). The root node is "All goals achieved". Each new node is added as either *mandatory* or *helpful* for at least one existing parent goal. A node can have multiple parents, so the same task can contribute to several higher goals at once.

### Status: Activation × Completion

A node's lifecycle is the combination of two orthogonal axes:

| Axis | Variants |
|---|---|
| **Activation** | *Always active* (default) · *Bounded* with an optional start and/or end date (either side can be open-ended) |
| **Completion** | *None* (background goal, no checkbox) · *One-time* · *N-times* (count-down) · *Periodic* (re-opens a fixed number of days after the last completion — the cadence is relative, not calendar-fixed) |

This lets you express e.g. "active only during May, must be done 3 times in that window" as a single node.

### Relationships between nodes

Beyond the structural parent/child edges, nodes can be linked via first-class relationships:

- **moreImportantThan / lessImportantThan** — directional; overrides the default ordering so the more-important node sorts above the other at the same level.
- **alternativeTo** — bidirectional; completing one automatically closes the other.

Drag-to-reorder in the todo list records `moreImportantThan` edges transparently.

### Additional properties

- **Impact** — a fixed five-level enum (minimal / low / medium / high / critical) used by the ordering algorithm.
- **Deadline** — drives urgency; tasks whose deadline is within the configurable "urgent window" (default 3 days) are promoted to the top of every list.
- **Inherited deadline / impact** — a leaf task without its own deadline inherits the earliest deadline among its ancestors; same for impact (strongest).
- **Attachments** — URL (including `obsidian://` links that open Obsidian), geo location, and time-trigger reminders.
- **Notification overrides** — per-node deadline lead time and periodic-reopen notification, falling back to global defaults.

### Ordering algorithm

1. **Tier 1 (urgent)**: tasks with a deadline within the configured urgent window, sorted by deadline ascending.
2. **Tier 2 (everything else)**: deadline ascending → impact descending → createdAt ascending.
3. **Importance relationships** act as topological overrides on top of the score-based sort.

In the hierarchical (tree) view, parent groups are ordered using *effective* scores: a parent's own deadline/impact wins when set, otherwise the most-urgent values are aggregated from its displayed descendants.

## Views

### Dashboard (home screen)

A responsive grid of tiles. Sources:

- **Built-in tiles**: "All ongoing", "All goals", "Graph".
- **Auto-tiles**: one per direct child of the root goal (Health, Work, Leisure, etc.).
- **User-saved tiles**: created via "Save as tile" in any list view's filter drawer.

Each tile shows an **actionable-task count badge** (ongoing leaves matching that tile's filter). Tiles are manageable (rename, delete, drag-reorder) via Settings → Manage saved tiles.

### Todo list (tap a tile)

A hierarchical indented tree of nodes matching the tile's filter. Features:

- **Depth-based indentation** with per-level ordering.
- **Drag handles** on every row for reordering siblings (records importance relationships).
- **Quick-add "+" button** on every row — one-field dialog (title + status chip), with "More options…" escape to the full form. Partial input is forwarded.
- **Leaf-only toggle** in the AppBar (one tap) — collapses the tree to only actionable items, hiding background goals.
- **Filter drawer** (tune icon): ongoing toggle, leaves toggle, ancestor-goal scope picker, contribution kind, completion/activation kind chips, free-text search.
- **"Save as tile"** button at the bottom of the filter drawer — saves the current refined filter as a new dashboard tile.
- **Checkbox** on completion-bearing tasks; **flag icon** on background goals; **lock icon** on goals whose mandatory children aren't all closed yet.
- Tapping a row opens the **Node detail view**.

### Node detail view

Inspector + action hub for a single node:

- Status summary with own and inherited deadline/impact.
- **Attachments** section — add URL (paste an `obsidian://` or `https://` link), open via OS handler, remove.
- **Parents** section — list with remove-edge action.
- **Relationships** section — list with remove + "Add" flow that offers 5 link kinds: *Depends on*, *Is a dependent of*, *More important than*, *Less important than*, *Alternative to*. The first two create structural edges (multi-parent); the rest create NodeRelationships.
- **Edit** (pencil icon) — full editor dialog covering title, description, activation (always/bounded with optional from/until), completion (one-time/n-times/periodic/background), impact, deadline, and per-node notification overrides.
- **Delete** (trash icon) — with confirmation; strips the node and every incident edge/relationship.

### Graph view

Pan/zoom-able Sugiyama (layered DAG) rendering via the `graphview` package. Nodes are styled by status (background / ongoing / completed / urgent / overdue) with hover-lift animations. Tapping a node opens the detail view.

### Settings

- **Urgent window** stepper (configurable days threshold).
- **Manage saved tiles** (rename, delete, drag-reorder presets).
- **Default notification settings** (deadline lead time, periodic-reopen toggle).
- **File sync** (Chromium browsers): pick a `.json` file on disk as the backing store via the File System Access API. The on-disk file survives browser data wipes — re-grant access after a wipe and your data is back. Also "Open existing file and sync…" to load from a previously-saved file.
- **Desktop file export/import** (macOS): native save/open panels via `file_selector`.
- **Clipboard export/import** — with schema validation and a confirmation dialog before replacing the current graph.

## Tech stack

- **Flutter 3.44 / Dart 3.12** — one codebase for web, iOS, Android, macOS desktop.
- **Persistence**: `SharedPreferencesGraphRepository` (all platforms, web via localStorage) or `LocalFileGraphRepository` (macOS, atomic temp-file-swap writes with sidecar backup). On Chromium browsers, an optional File-System-Access-API repository writes to a real on-disk file that survives browser data wipes.
- **Data model**: hand-written sealed-class hierarchy in `lib/model/`. The JSON Schema at `schema/lakshya.schema.json` is the documented wire format and is used for runtime validation (via the `json_schema` package).
- **Graph engine**: `GraphTraversal`, `FilterEvaluator`, `NodeOrdering`, `HierarchicalOrdering`, `GraphMutator`, `NodeQueries` — all pure-functional services with full test coverage.
- **State management**: `GraphController` (a `ChangeNotifier`) owns the in-memory graph, routes mutations through `GraphMutator`, and persists via a rebindable save callback. Save errors are broadcast via a `Stream<Object>` and surfaced as SnackBars.
- **First-run seed**: `assets/example_seed.json` — a hand-editable JSON file loaded and schema-validated on first launch. Edit in place to change the initial dataset without touching Dart code.
- **Schema migration**: `GraphDocumentMigrator` upgrades older schema versions on load/import so saved data isn't lost across data-model changes.
- **No backend**. The repository layer is behind an interface so cloud sync can be added later without touching the rest of the app.

## Architecture and quality principles

1. **Test-driven development.** Write the failing test first. 240+ unit and widget tests.
2. **Layered architecture.** `model` → `repository` → `service` → `app` → `view` / `widgets` / `theme`. Higher layers depend on lower layers, never the reverse.
3. **Readable names over short names.** `intervalDaysSinceLastCompletion`, not `interval`.
4. **Dependency injection over globals.** Services, repositories, and the clock are passed in.
5. **Small, single-purpose functions.** Shared helpers in `lib/view/view_helpers.dart` and `lib/service/compare_utils.dart` — no duplication across view files.
6. **Schema-first data model.** Changes start in the JSON Schema, then are reflected by hand in Dart with matching tests.
7. **No legacy code while pre-release.** One source of truth, always current. Migrators exist only for the schema-version upgrade path (v1 → v2), not for deprecated shapes.

## Repository layout

```
lakshya/
  schema/
    lakshya.schema.json       # documented wire format + runtime validation
  assets/
    example_seed.json          # first-run seed graph (hand-editable)
  lib/
    model/                     # sealed-class data model (Node, Edge, NodeStatus, etc.)
    repository/                # GraphRepository interface + implementations
    service/                   # graph engine, filters, ordering, queries, schema validation
    app/                       # GraphController, LakshyaApp, WebFileSyncCoordinator
    view/                      # screens (dashboard, todo list, detail, graph, settings, etc.)
    widgets/                   # reusable widgets (node picker)
    theme/                     # Shiva-themed Material 3 color palette
  test/
    model/                     # model unit tests
    repository/                # repository unit tests
    service/                   # service unit tests
    widget/                    # widget tests
    support/                   # shared test builders (buildNode, buildEdge, buildGraph)
```

## Development setup

```bash
flutter pub get
flutter test                     # run all ~240 tests
flutter run -d chrome --web-port=8080   # web (pin port for localStorage persistence)
flutter run -d macos             # native macOS (requires Xcode)
```

To change the data model:

1. Update `schema/lakshya.schema.json` (the documented wire format).
2. Reflect in the matching Dart classes under `lib/model/`.
3. Add/update tests under `test/model/`.
4. If the schema version changed, add a migration step in `lib/service/graph_document_migrator.dart`.
5. Run `flutter analyze` and `flutter test`.

## Status

Project started 2026-05-24. Pre-release (dogfooding).

**Implemented:**

- Full data model with composable ActivationWindow × Completion, relationships, attachments, notification overrides.
- Complete graph engine: traversal, filtering (including timewise-inactive hiding for past/future bounded windows), hierarchical ordering with effective-score aggregation, cycle-safe mutation.
- Dashboard with count badges, auto-tiles per root child, user-saved tiles with rename/delete/reorder.
- Hierarchical todo list with drag-to-reorder, quick-add, leaf-toggle, filter drawer with save-as-tile.
- Node detail view with full property editor, attachment management (incl. Obsidian links), relationship CRUD (structural + importance + alternative), delete with confirmation.
- Graph canvas (Sugiyama layout, status-aware styling, hover animations).
- Atomic file persistence (macOS) with sidecar backup + corrupt-file recovery.
- File-System-Access-API sync for Chromium browsers (survives localStorage wipes).
- Desktop file export/import via native save/open panels.
- Clipboard export/import with schema validation + confirmation dialog.
- Schema migration (v1 → v2).
- Data-integrity: save-error broadcasting via SnackBar, import confirmation, numeric input validation.
- 240+ tests covering model, services, repositories, and widgets.

**Not yet started:** PWA manifest + service worker, app logo/icon, mobile-specific responsive layout, cloud sync, local push notifications (platform integration).
