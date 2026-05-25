import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/cloud_sync_coordinator.dart';
import '../app/graph_controller.dart';
import '../app/web_file_sync_coordinator.dart';
import '../model/settings.dart';
import '../repository/graph_repository.dart';
import '../service/cloud_sync_provider.dart';
import '../service/cloud_sync_registry.dart';
import '../service/desktop_graph_file_io.dart';
import '../service/graph_io.dart';
import '../service/schema_validator.dart';
import 'manage_presets_view.dart';

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
    this.cloudSyncRegistry,
    this.cloudSyncCoordinator,
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

  /// Declarative registry of API-based cloud providers.
  final CloudSyncRegistry? cloudSyncRegistry;

  /// Runtime coordinator for API-based cloud sync.
  final CloudSyncCoordinator? cloudSyncCoordinator;

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
    try {
      await DesktopGraphFileIo(graphIo: GraphIo(validator: validator))
          .exportToFile(graph: widget.controller.graph, path: path);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Graph exported to $path')),
      );
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog('Export failed', e.toString());
    }
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
      if (!mounted) return;
      final confirmed = await _confirmReplaceCurrentGraph(
        imported: imported,
        source: 'clipboard',
      );
      if (!confirmed || !mounted) return;
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
    } catch (e) {
      if (!mounted) return;
      await _showErrorDialog('Import failed', e.toString());
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
      if (!mounted) return;
      final confirmed = await _confirmReplaceCurrentGraph(
        imported: imported,
        source: path,
      );
      if (!confirmed || !mounted) return;
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
    } catch (e) {
      // FileSystemException, permission denied, etc.
      if (!mounted) return;
      await _showErrorDialog('Import failed', e.toString());
    }
  }

  Future<bool> _confirmReplaceCurrentGraph({
    required dynamic imported,
    required String source,
  }) async {
    final currentNodes = widget.controller.graph.nodes.length;
    final currentEdges = widget.controller.graph.edges.length;
    final incomingNodes = imported.nodes.length as int;
    final incomingEdges = imported.edges.length as int;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Replace current graph?'),
        content: Text(
          'This permanently replaces your current graph '
          '($currentNodes nodes, $currentEdges edges) with the content from '
          '$source ($incomingNodes nodes, $incomingEdges edges).\n\n'
          'Consider exporting the current graph first if you want to keep '
          'a backup.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Replace'),
          ),
        ],
      ),
    );
    return result ?? false;
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

  Future<void> _showCloudProviderInfo(
    CloudSyncProviderDescriptor descriptor,
  ) async {
    final title = switch (descriptor.id) {
      CloudSyncProviderId.iCloud => 'Apple iCloud',
    };
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(
            '${descriptor.statusMessage}\n\n${descriptor.setupHint}',
          ),
        ),
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
              _DeadlineLeadTimeTile(
                value: settings.defaultDeadlineLeadTimeHours,
                onChanged: _setDefaultDeadlineLeadTimeHours,
              ),
              _PeriodicReopenDefaultTile(
                value: settings.notifyOnPeriodicReopenByDefault,
                onChanged: _setNotifyOnPeriodicReopenByDefault,
              ),
              ListTile(
                leading: const Icon(Icons.dashboard_customize_outlined),
                title: const Text('Manage saved tiles'),
                subtitle: Text(
                  widget.controller.graph.filterPresets.isEmpty
                      ? 'No tiles saved yet'
                      : '${widget.controller.graph.filterPresets.length} '
                          'saved tile'
                          '${widget.controller.graph.filterPresets.length == 1
                              ? ''
                              : 's'} — rename, reorder, delete',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        ManagePresetsView(controller: widget.controller),
                  ),
                ),
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
              if (widget.cloudSyncRegistry != null) ...[
                _CloudProviderSection(
                  registry: widget.cloudSyncRegistry!,
                  coordinator: widget.cloudSyncCoordinator,
                  onMessage: _showSnack,
                  onError: _showErrorDialog,
                  onInfo: _showCloudProviderInfo,
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
    widget.controller.updateSettings(next);
  }

  void _setDefaultDeadlineLeadTimeHours(int? hours) {
    final current = widget.controller.graph.settings ?? const Settings();
    widget.controller.updateSettings(
      current.copyWith(defaultDeadlineLeadTimeHours: hours),
    );
  }

  void _setNotifyOnPeriodicReopenByDefault(bool? value) {
    final current = widget.controller.graph.settings ?? const Settings();
    widget.controller.updateSettings(
      current.copyWith(notifyOnPeriodicReopenByDefault: value),
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

  Future<void> _connectNewFile({bool explainCloudFlow = false}) async {
    try {
      final connected = await coordinator.startSyncToNewFile(
        suggestedName: suggestedFileName,
      );
      if (!connected) {
        onMessage('File pick was cancelled');
        return;
      }
      final file = coordinator.currentFileName ?? 'the picked file';
      onMessage(explainCloudFlow
          ? 'Now syncing to $file. If it lives in a cloud-synced folder, '
              'your cloud service will mirror it too.'
          : 'Now syncing to $file');
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

  Future<void> _connectCloudBackedFile(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Pick a cloud-backed file'),
        content: const Text(
          'Lakshya does not log into Dropbox, Google Drive, OneDrive, or '
          'iCloud directly. Instead, pick a file inside a folder those '
          'services already sync on this device.\n\n'
          'Examples: iCloud Drive, Dropbox, OneDrive, or Google Drive for '
          'Desktop.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Pick file'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _connectNewFile(explainCloudFlow: true);
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
              title: const Text('Sync to a file'),
              subtitle: Text(active
                  ? 'Saving to "$fileName" on every change. Survives '
                      'browser data wipes — re-grant access after a wipe '
                      'and your data is back.'
                  : 'Pick a .json file once; the app writes to it on every '
                      'change. The file lives outside the browser so it '
                      'survives any data wipe. You can also place that file '
                      'inside a cloud-synced folder.'),
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
                        ? 'Switch synced file…'
                        : 'Create file and sync…'),
                    onPressed: _connectNewFile,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.cloud_sync_outlined),
                    label: Text(active
                        ? 'Use a cloud-backed file…'
                        : 'Create cloud-backed file…'),
                    onPressed: () => _connectCloudBackedFile(context),
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

class _CloudProviderSection extends StatelessWidget {
  const _CloudProviderSection({
    required this.registry,
    required this.coordinator,
    required this.onMessage,
    required this.onError,
    required this.onInfo,
  });

  final CloudSyncRegistry registry;
  final CloudSyncCoordinator? coordinator;
  final ValueChanged<String> onMessage;
  final Future<void> Function(String title, String body) onError;
  final ValueChanged<CloudSyncProviderDescriptor> onInfo;

  Future<void> _connectICloud() async {
    final sync = coordinator;
    if (sync == null) {
      await onError(
        'Cloud sync unavailable',
        'No cloud sync coordinator is configured for this app run.',
      );
      return;
    }
    try {
      await sync.startICloudSync();
      onMessage(
        'Now syncing directly with Apple iCloud. The file-based sync options '
        'remain available separately.',
      );
    } catch (e) {
      await onError('Could not start iCloud sync', e.toString());
    }
  }

  Future<void> _disconnectICloud() async {
    final sync = coordinator;
    if (sync == null) return;
    await sync.stopSync();
    onMessage('Stopped iCloud sync — saves now go back to the default storage.');
  }

  @override
  Widget build(BuildContext context) {
    final descriptors = registry.describeAll();
    final sync = coordinator;
    Widget content() => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ListTile(
              leading: Icon(Icons.cloud_queue_outlined),
              title: Text('Cloud provider sync'),
              subtitle: Text(
                'Experimental API-based iCloud sync. Requires a CloudKit '
                'container and web API token.',
              ),
            ),
            for (final descriptor in descriptors)
              ListTile(
                leading: Icon(
                  switch (descriptor.status) {
                    CloudSyncProviderStatus.readyForImplementation =>
                      (sync?.isICloudActive ?? false)
                          ? Icons.cloud_done_outlined
                          : Icons.check_circle_outline,
                    CloudSyncProviderStatus.missingConfiguration =>
                      Icons.vpn_key_outlined,
                    CloudSyncProviderStatus.unsupportedPlatform =>
                      Icons.block_outlined,
                  },
                ),
                title: Text(descriptor.title),
                subtitle: Text(
                  '${descriptor.subtitle}\n'
                  '${descriptor.statusMessage}'
                  '${sync?.isICloudActive == true ? '\nCurrently active.' : ''}',
                ),
                isThreeLine: true,
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    if (descriptor.canStartIntegration && sync != null)
                      TextButton(
                        onPressed: sync.isICloudActive
                            ? _disconnectICloud
                            : _connectICloud,
                        child: Text(sync.isICloudActive ? 'Stop' : 'Connect'),
                      ),
                    TextButton(
                      onPressed: () => onInfo(descriptor),
                      child: Text(
                        descriptor.canStartIntegration ? 'Details' : 'Setup',
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
    if (sync == null) return content();
    return ListenableBuilder(
      listenable: sync,
      builder: (context, _) => content(),
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

class _DeadlineLeadTimeTile extends StatelessWidget {
  const _DeadlineLeadTimeTile({
    required this.value,
    required this.onChanged,
  });

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final effective = value ?? 24;
    return ListTile(
      leading: const Icon(Icons.notifications_active_outlined),
      title: const Text('Default deadline reminder'),
      subtitle: Text(
        value == null
            ? 'Using the default 24-hour lead time.'
            : 'Remind $effective hour${effective == 1 ? '' : 's'} before each deadline unless a task overrides it.',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Use app default',
            icon: const Icon(Icons.restart_alt),
            visualDensity: VisualDensity.compact,
            onPressed: value == null ? null : () => onChanged(null),
          ),
          IconButton(
            icon: const Icon(Icons.remove),
            visualDensity: VisualDensity.compact,
            onPressed: effective > 0 ? () => onChanged(effective - 1) : null,
          ),
          Text('$effective', style: Theme.of(context).textTheme.titleMedium),
          IconButton(
            icon: const Icon(Icons.add),
            visualDensity: VisualDensity.compact,
            onPressed: () => onChanged(effective + 1),
          ),
        ],
      ),
    );
  }
}

class _PeriodicReopenDefaultTile extends StatelessWidget {
  const _PeriodicReopenDefaultTile({
    required this.value,
    required this.onChanged,
  });

  final bool? value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.autorenew_outlined),
      title: const Text('Periodic reopen notifications'),
      subtitle: Text(
        switch (value) {
          true => 'Always notify when periodic tasks become open again.',
          false => 'Do not notify when periodic tasks reopen unless a task overrides it.',
          null => 'Using the app default behavior for periodic reopen notifications.',
        },
      ),
      trailing: DropdownButton<bool?>(
        value: value,
        onChanged: onChanged,
        items: const [
          DropdownMenuItem<bool?>(
            value: null,
            child: Text('App default'),
          ),
          DropdownMenuItem<bool?>(
            value: true,
            child: Text('Always notify'),
          ),
          DropdownMenuItem<bool?>(
            value: false,
            child: Text('Do not notify'),
          ),
        ],
      ),
    );
  }
}
