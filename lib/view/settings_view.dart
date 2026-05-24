import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/graph_controller.dart';
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
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.copy_outlined),
            title: const Text('Export to JSON'),
            subtitle: const Text('Copies the full graph to your clipboard'),
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
      ),
    );
  }
}
