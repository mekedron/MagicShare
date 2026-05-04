import 'package:flutter/material.dart';
import 'package:magicshare_app/config/theme.dart';
import 'package:magicshare_app/gen/strings.g.dart';
import 'package:routerino/routerino.dart';

/// Action chosen in the device-detail bottom sheet. Returned via
/// [Navigator.pop] / [BuildContext.pop] so the caller can decide which
/// follow-up dialog to launch.
enum CloudDeviceAction {
  rename,
  changeIcon,
  removeFromGroup,
  leaveOrDestroy,
}

/// Bottom sheet shown when a device tile is tapped. Branches on whether
/// the tile represents the current device or a peer.
class CloudDeviceDetailSheet extends StatelessWidget {
  final String deviceName;
  final bool isCurrent;

  const CloudDeviceDetailSheet({
    required this.deviceName,
    required this.isCurrent,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l = t.settingsTab.deviceGroup.actions;
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                deviceName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(l.rename),
              onTap: () => context.pop(CloudDeviceAction.rename),
            ),
            ListTile(
              leading: const Icon(Icons.devices_outlined),
              title: Text(l.changeIcon),
              onTap: () => context.pop(CloudDeviceAction.changeIcon),
            ),
            if (isCurrent)
              ListTile(
                leading: Icon(Icons.logout, color: scheme.warning),
                title: Text(l.leaveOrDestroy, style: TextStyle(color: scheme.warning)),
                onTap: () => context.pop(CloudDeviceAction.leaveOrDestroy),
              )
            else
              ListTile(
                leading: Icon(Icons.delete_outline, color: scheme.warning),
                title: Text(l.removeFromGroup, style: TextStyle(color: scheme.warning)),
                onTap: () => context.pop(CloudDeviceAction.removeFromGroup),
              ),
          ],
        ),
      ),
    );
  }
}
