import 'package:flutter/material.dart';
import 'package:magicshare_app/config/theme.dart';
import 'package:magicshare_app/gen/strings.g.dart';
import 'package:routerino/routerino.dart';

/// Confirmation for *Leave or destroy this group* on the current device.
/// Pops `true` on confirm, `false` on cancel.
class CloudDeviceLeaveDialog extends StatelessWidget {
  const CloudDeviceLeaveDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t.settingsTab.deviceGroup.leaveDialog.title),
      content: Text(t.settingsTab.deviceGroup.leaveDialog.body),
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
          child: Text(t.settingsTab.deviceGroup.leaveDialog.confirm),
        ),
      ],
    );
  }
}
