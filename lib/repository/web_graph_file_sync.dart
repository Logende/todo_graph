library;

/// Facade for "use a real file on the user's disk as the backing store".
///
/// Has two implementations, selected at compile time:
/// * `web_graph_file_sync_web.dart` — uses the browser's File System Access
///   API (Chrome/Edge/etc.). The on-disk file survives any browser data wipe
///   because it isn't stored in browser state — only the handle is, and the
///   user can re-grant access to the same file after a wipe.
/// * `web_graph_file_sync_stub.dart` — used on every non-web target. Reports
///   `isSupported == false` and refuses to do anything.
export 'web_graph_file_sync_stub.dart'
    if (dart.library.js_interop) 'web_graph_file_sync_web.dart';
