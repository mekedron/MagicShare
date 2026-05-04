import 'package:flutter/material.dart';
import 'package:magicshare_app/config/theme.dart';
import 'package:magicshare_app/gen/strings.g.dart';
import 'package:routerino/routerino.dart';

/// Confirmation for *Delete this device group*. Pops `true` on confirm,
/// `false` on cancel.
class DeleteDeviceGroupDialog extends StatelessWidget {
  const DeleteDeviceGroupDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t.settingsTab.deviceGroup.deleteGroupDialog.title),
      content: Text(t.settingsTab.deviceGroup.deleteGroupDialog.body),
      actions: [
        TextButton(
          onPressed: () => context.pop(false),
          child: Text(t.general.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.warning,
          ),
          onPressed: () => context.pop(true),
          child: Text(t.settingsTab.deviceGroup.deleteGroupDialog.confirm),
        ),
      ],
    );
  }
}
