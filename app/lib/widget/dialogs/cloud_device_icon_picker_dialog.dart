import 'package:flutter/material.dart';
import 'package:magicshare_app/gen/strings.g.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/widget/cloud/cloud_device_icon_data.dart';
import 'package:routerino/routerino.dart';

/// Pops with the chosen [CloudDeviceIcon] on tap, or `null` on cancel.
class CloudDeviceIconPickerDialog extends StatelessWidget {
  final CloudDeviceIcon current;

  const CloudDeviceIconPickerDialog({required this.current, super.key});

  String _label(CloudDeviceIcon icon) {
    final l = t.settingsTab.deviceGroup.iconPickerDialog.icons;
    return switch (icon) {
      CloudDeviceIcon.laptop => l.laptop,
      CloudDeviceIcon.desktop => l.desktop,
      CloudDeviceIcon.phone => l.phone,
      CloudDeviceIcon.tablet => l.tablet,
      CloudDeviceIcon.server => l.server,
      CloudDeviceIcon.headless => l.headless,
      CloudDeviceIcon.other => l.other,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t.settingsTab.deviceGroup.iconPickerDialog.title),
      content: SingleChildScrollView(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final icon in CloudDeviceIcon.values)
              _IconChoice(
                icon: icon,
                label: _label(icon),
                selected: icon == current,
                onTap: () => context.pop(icon),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: Text(t.general.cancel),
        ),
      ],
    );
  }
}

class _IconChoice extends StatelessWidget {
  final CloudDeviceIcon icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _IconChoice({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = selected ? scheme.primaryContainer : scheme.surfaceContainerHighest;
    final foreground = selected ? scheme.onPrimaryContainer : scheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconDataFor(icon), size: 32, color: foreground),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: foreground, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
