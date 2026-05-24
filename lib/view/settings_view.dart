import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/graph_controller.dart';
import '../model/settings.dart';
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
/// File-picker plumbing for desktop/mobile is deferred to a follow-up; the
/// clipboard path keeps the implementation cross-platform without extra
/// plugins and is enough to support backup/restore today.
class SettingsView extends StatefulWidget {
  const SettingsView({
    super.key,
    required this.controller,
    SchemaValidator? validator,
  }) : _injectedValidator = validator;

  final GraphController controller;
  final SchemaValidator? _injectedValidator;

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
