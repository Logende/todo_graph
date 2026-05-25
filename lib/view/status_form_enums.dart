/// UI-side selectors for the activation axis. Shared between AddNodeView
/// and NodeEditorDialog.
enum ActivationChoice { alwaysActive, bounded }

/// UI-side selectors for the completion axis. `none` means "background goal".
/// Shared between AddNodeView and NodeEditorDialog.
enum CompletionChoice { none, oneTime, nTimes, periodic }
