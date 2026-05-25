library;

/// Centralized layout constants. Change here to adjust the whole app's
/// spacing and breakpoints without hunting through individual view files.
///
/// Constants are grouped by concern. Widget files import this and reference
/// the named constant instead of hard-coding a number.

// ---------------------------------------------------------------------------
// Responsive breakpoints (screen width in logical pixels)
// ---------------------------------------------------------------------------

/// Below this the UI enters "narrow" / mobile mode: reduced indentation,
/// hidden status badges, smaller icons.
const double kNarrowScreenBreakpoint = 500;

/// Dashboard: 3 columns above this, 2 below.
const double kMediumScreenBreakpoint = 600;

/// Dashboard: 4 columns above this.
const double kWideScreenBreakpoint = 900;

// ---------------------------------------------------------------------------
// Todo list: hierarchical indentation
// ---------------------------------------------------------------------------

/// Horizontal pixels per depth level on screens wider than
/// [kNarrowScreenBreakpoint].
const double kIndentPerLevelWide = 16;

/// Horizontal pixels per depth level on narrow screens.
const double kIndentPerLevelNarrow = 10;

/// Maximum depth that still receives additional indentation. Levels beyond
/// this are rendered at the same indent so the title text stays readable.
const int kMaxDisplayDepth = 8;

// ---------------------------------------------------------------------------
// Dashboard tile grid
// ---------------------------------------------------------------------------

/// Width-to-height ratio of each dashboard tile.
const double kTileAspectRatio = 1.4;

/// Space between tiles in the grid.
const double kTileGridSpacing = 12;

/// Padding around the entire tile grid.
const double kTileGridPadding = 16;

// ---------------------------------------------------------------------------
// Graph canvas (Sugiyama layout)
// ---------------------------------------------------------------------------

/// Horizontal separation between sibling nodes in the graph view.
const int kGraphNodeSeparation = 52;

/// Vertical separation between hierarchy levels.
const int kGraphLevelSeparation = 80;

/// Minimum zoom scale in the interactive graph viewer.
const double kGraphMinScale = 0.3;

/// Maximum zoom scale in the interactive graph viewer.
const double kGraphMaxScale = 4.0;

/// Extra scrollable margin around the graph so edge nodes aren't clipped.
const double kGraphBoundaryMargin = 400;

/// Padding inside the graph viewport.
const double kGraphInternalPadding = 48;

/// Node box width constraints in the graph view.
const double kGraphNodeMinWidth = 160;
const double kGraphNodeMaxWidth = 240;
const double kGraphNodeMinHeight = 56;

// ---------------------------------------------------------------------------
// Icon sizes
// ---------------------------------------------------------------------------

/// Icon size for compact trailing actions on narrow screens.
const double kCompactIconSize = 18;

/// Default icon size.
const double kDefaultIconSize = 24;

// ---------------------------------------------------------------------------
// Durations
// ---------------------------------------------------------------------------

/// How long the completion-undo SnackBar stays visible before auto-dismissing.
const Duration kUndoSnackBarDuration = Duration(seconds: 5);

/// How long the recovery-notice SnackBar stays on first launch.
const Duration kRecoveryNoticeDuration = Duration(seconds: 8);

/// How long the save-error SnackBar stays visible.
const Duration kSaveErrorDuration = Duration(seconds: 6);

// ---------------------------------------------------------------------------
// Animation
// ---------------------------------------------------------------------------

/// Duration of the hover-scale animation on dashboard tiles and graph nodes.
const Duration kHoverScaleDuration = Duration(milliseconds: 160);

/// Duration of the color/shadow transition on hover.
const Duration kHoverColorDuration = Duration(milliseconds: 200);

/// Scale factor when hovering over a dashboard tile.
const double kTileHoverScale = 1.025;

/// Scale factor when hovering over a graph node.
const double kGraphNodeHoverScale = 1.04;

// ---------------------------------------------------------------------------
// Contribution border
// ---------------------------------------------------------------------------

/// Width of the left-edge border indicating mandatory vs helpful on task rows.
const double kContributionBorderWidth = 3;
