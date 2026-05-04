import 'package:flutter/material.dart';
import 'package:magicshare_app/gen/strings.g.dart';
import 'package:routerino/routerino.dart';

/// Backend-validated cap is 50 chars. Match it client-side so the user
/// cannot submit a name that the cloud function would reject anyway.
const int _displayNameMaxLength = 50;

/// Pops with the new (trimmed) display name on save, or `null` on cancel.
/// The dialog itself does NOT call `renameDevice`; the caller dispatches.
class CloudDeviceRenameDialog extends StatefulWidget {
  final String initialName;

  const CloudDeviceRenameDialog({required this.initialName, super.key});

  @override
  State<CloudDeviceRenameDialog> createState() => _CloudDeviceRenameDialogState();
}

class _CloudDeviceRenameDialogState extends State<CloudDeviceRenameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSave => _controller.text.trim().isNotEmpty;

  void _save() {
    final trimmed = _controller.text.trim();
    if (trimmed.isEmpty) return;
    context.pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t.settingsTab.deviceGroup.renameDialog.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.settingsTab.deviceGroup.renameDialog.label),
          const SizedBox(height: 5),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: _displayNameMaxLength,
            onSubmitted: (_) {
              if (_canSave) _save();
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(t.general.cancel),
        ),
        FilledButton(
          onPressed: _canSave ? _save : null,
          child: Text(t.settingsTab.deviceGroup.renameDialog.save),
        ),
      ],
    );
  }
}
