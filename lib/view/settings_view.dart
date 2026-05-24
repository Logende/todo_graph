import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/graph_controller.dart';
import '../app/web_file_sync_coordinator.dart';
import '../model/settings.dart';
import '../repository/graph_repository.dart';
import '../service/desktop_graph_file_io.dart';
import '../service/graph_io.dart';
import '../service/schema_validator.dart';

/// Global settings + JSON Export/Import.
///
/// Export is one-tap: the full graph is copied to the clipboard as
/// pretty-printed JSON the user can paste anywhere. Import takes whatever is
/// currently on the clipboard, validates it against the bundled schema, and
/// replaces the in-memory graph on success. Validation errors are shown in a
/// dialog rather than silently dropping fields.
///
typedef JsonExportPathPicker = Future<String?> Function(String suggestedName);
typedef JsonImportPathPicker = Future<String?> Function();

class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    required this.controller,
    SchemaValidator? validator,
    this.pickExportPath,
    this.pickImportPath,
    this.showDesktopFileActions,
    this.webFileSync,
    this.fallbackRepository,
  }) : _injectedValidator = validator;

  final GraphController controller;
  final SchemaValidator? _injectedValidator;
  final JsonExportPathPicker? pickExportPath;
  final JsonImportPathPicker? pickImportPath;
  final bool? showDesktopFileActions;

  /// Optional File-System-Access coordinator. When supplied AND the browser
  /// reports `isSupported`, the settings screen surfaces a "Sync to a file
  /// on disk" section that survives browser data wipes.
  final WebFileSyncCoordinator? webFileSync;

  /// The repository the controller falls back to when web file sync is
  /// disconnected.
  final GraphRepository? fallbackRepository;

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  SchemaValidator? _validator;

  @override
  void initState() {
    super.initState();
    _validator = widget._injectedValidator;
    if (_validator == null) {
      _loadValidator();
    }
  }

  Future<void> _loadValidator() async {
    final schemaText =
        await rootBundle.loadString('schema/lakshya.schema.json');
    if (!mounted) return;
    setState(() {
      _validator = SchemaValidator.fromString(schemaText);
    });
  }

  Future<void> _export() async {
    final validator = _validator;
    if (validator == null) return;
    final io = GraphIo(validator: validator);
    final text = io.exportToJson(widget.controller.graph);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Graph copied to clipboard as JSON')),
    );
  }

  Future<void> _exportToFile() async {
    final validator = _validator;
    if (validator == null) return;
    final pickPath = widget.pickExportPath ?? _defaultPickExportPath;
    final path = await pickPath(_suggestedExportFileName());
    if (path == null || path.trim().isEmpty) return;
    await DesktopGraphFileIo(graphIo: GraphIo(validator: validator))
        .exportToFile(graph: widget.controller.graph, path: path);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Graph exported to $path')),
    );
  }

  Future<void> _import() async {
    final validator = _validator;
    if (validator == null) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard is empty')),
      );
      return;
    }
    try {
      final imported = GraphIo(validator: validator).importFromJson(text);
      widget.controller.replaceWith(imported);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Graph imported')),
      );
    } on SchemaValidationException catch (e) {
      if (!mounted) return;
      await _showErrorDialog(
        'Import rejected: invalid schema',
        e.errors.join('\n'),
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      await _showErrorDialog('Import rejected: malformed JSON', e.message);
    }
  }

  Future<void> _importFromFile() async {
    final validator = _validator;
    if (validator == null) return;
    final pickPath = widget.pickImportPath ?? _defaultPickImportPath;
    final path = await pickPath();
    if (path == null || path.trim().isEmpty) return;
    try {
      final imported = await DesktopGraphFileIo(
        graphIo: GraphIo(validator: validator),
      ).importFromFile(path);
      widget.controller.replaceWith(imported);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Graph imported from $path')),
      );
    } on SchemaValidationException catch (e) {
      if (!mounted) return;
      await _showErrorDialog(
        'Import rejected: invalid schema',
        e.errors.join('\n'),
      );
    } on FormatException catch (e) {
      if (!mounted) return;
      await _showErrorDialog('Import rejected: malformed JSON', e.message);
    }
  }

  Future<String?> _defaultPickExportPath(String suggestedName) async {
    final location = await getSaveLocation(
      suggestedName: suggestedName,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
    );
    return location?.path;
  }

  Future<String?> _defaultPickImportPath() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(label: 'JSON', extensions: ['json']),
      ],
      confirmButtonText: 'Import',
    );
    return file?.path;
  }

  bool get _showDesktopFileActions =>
      widget.showDesktopFileActions ??
      (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS);

  String _suggestedExportFileName() {
    final now = widget.controller.clock();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return 'lakshya-$y-$m-$d.json';
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _showErrorDialog(String title, String body) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final settings = widget.controller.graph.settings ?? const Settings();
          return ListView(
            children: [
              _UrgentWindowTile(
                value: settings.effectiveUrgentWindowDays,
                onChanged: _setUrgentWindow,
              ),
              const Divider(),
              if (widget.webFileSync != null &&
                  widget.webFileSync!.isSupported) ...[
                _WebFileSyncSection(
                  coordinator: widget.webFileSync!,
                  fallbackRepository: widget.fallbackRepository,
                  suggestedFileName: _suggestedExportFileName(),
                  onMessage: _showSnack,
                  onError: _showErrorDialog,
                ),
                const Divider(),
              ],
              if (_showDesktopFileActions) ...[
                ListTile(
                  leading: const Icon(Icons.upload_file_outlined),
                  title: const Text('Export to JSON file'),
                  subtitle: const Text(
                    'Saves the full graph to a .json file on disk',
                  ),
                  enabled: _validator != null,
                  onTap: _validator == null ? null : _exportToFile,
                ),
                ListTile(
                  leading: const Icon(Icons.file_open_outlined),
                  title: const Text('Import from JSON file'),
                  subtitle: const Text(
                    'Loads a .json file from disk, validates it, then '
                    'replaces the current graph',
                  ),
                  enabled: _validator != null,
                  onTap: _validator == null ? null : _importFromFile,
                ),
                const Divider(),
              ],
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Export to JSON'),
                subtitle:
                    const Text('Copies the full graph to your clipboard'),
                enabled: _validator != null,
                onTap: _validator == null ? null : _export,
              ),
              ListTile(
                leading: const Icon(Icons.download_outlined),
                title: const Text('Import from JSON'),
                subtitle: const Text(
                  'Validates the clipboard contents against the schema, then '
                  'replaces the current graph',
                ),
                enabled: _validator != null,
                onTap: _validator == null ? null : _import,
              ),
            ],
          );
        },
      ),
    );
  }

  void _setUrgentWindow(int days) {
    final current = widget.controller.graph.settings ?? const Settings();
    final next = current.copyWith(urgentWindowDays: days);
    widget.controller.replaceWith(
      widget.controller.graph.copyWith(settings: next),
    );
  }
}

/// UI for connecting the running app to a real on-disk file via the browser
/// File System Access API. Persists across browser data wipes because the
/// file lives on disk, not in browser storage.
class _WebFileSyncSection extends StatelessWidget {
  const _WebFileSyncSection({
    required this.coordinator,
    required this.fallbackRepository,
    required this.suggestedFileName,
    required this.onMessage,
    required this.onError,
  });

  final WebFileSyncCoordinator coordinator;
  final GraphRepository? fallbackRepository;
  final String suggestedFileName;
  final ValueChanged<String> onMessage;
  final Future<void> Function(String title, String body) onError;

  Future<void> _connect() async {
    try {
      final connected = await coordinator.startSyncToNewFile(
        suggestedName: suggestedFileName,
      );
      onMessage(connected
          ? 'Now syncing to ${coordinator.currentFileName ?? "the picked file"}'
          : 'File pick was cancelled');
    } catch (e) {
      await onError('Could not start file sync', e.toString());
    }
  }

  Future<void> _openExisting() async {
    try {
      final connected = await coordinator.startSyncFromExistingFile();
      onMessage(connected
          ? 'Loaded ${coordinator.currentFileName ?? "the picked file"} and '
              'now syncing to it'
          : 'File pick was cancelled');
    } catch (e) {
      await onError('Could not open file', e.toString());
    }
  }

  Future<void> _disconnect() async {
    final fallback = fallbackRepository;
    if (fallback == null) {
      await onError(
        'No fallback storage available',
        'Disconnecting now would leave the app with no place to save.',
      );
      return;
    }
    await coordinator.stopSync(fallback: fallback);
    onMessage('Stopped file sync — saves now go to browser storage');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: coordinator,
      builder: (context, _) {
        final fileName = coordinator.currentFileName;
        final active = coordinator.isActive;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Icon(
                active ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              ),
              title: const Text('Sync to a file on disk'),
              subtitle: Text(active
                  ? 'Saving to "$fileName" on every change. Survives '
                      'browser data wipes — re-grant access after a wipe '
                      'and your data is back.'
                  : 'Pick a .json file once; the app writes to it on every '
                      'change. The file lives outside the browser so it '
                      'survives any data wipe.'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    icon: const Icon(Icons.save_outlined),
                    label: Text(active
                        ? 'Save to a different file…'
                        : 'Save current graph to a file…'),
                    onPressed: _connect,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.file_open_outlined),
                    label: Text(active
                        ? 'Open a different existing file…'
                        : 'Open existing file and sync…'),
                    onPressed: _openExisting,
                  ),
                  if (active)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.link_off),
                      label: const Text('Stop file sync'),
                      onPressed: _disconnect,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

/// Editor for the "tasks due within N days are urgent" threshold.
class _UrgentWindowTile extends StatelessWidget {
  const _UrgentWindowTile({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.bolt_outlined),
      title: const Text('Urgent window'),
      subtitle: Text(
        'Tasks due within $value day${value == 1 ? '' : 's'} are surfaced '
        'at the top of every list.',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove),
            visualDensity: VisualDensity.compact,
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
          ),
          Text('$value', style: Theme.of(context).textTheme.titleMedium),
          IconButton(
            icon: const Icon(Icons.add),
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}
