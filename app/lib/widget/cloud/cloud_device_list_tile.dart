import 'package:flutter/material.dart';
import 'package:magicshare_app/model/cloud/cloud_device.dart';
import 'package:magicshare_app/model/cloud/cloud_device_presence.dart';
import 'package:magicshare_app/widget/cloud/cloud_device_icon_data.dart';
import 'package:magicshare_app/widget/list_tile/custom_list_tile.dart';

/// Renders a single device row in the device-group settings section. Pure
/// presentation: all label strings are passed in so the widget itself
/// stays free of localization lookups (and easy to widget-test in any
/// locale).
class CloudDeviceListTile extends StatelessWidget {
  final CloudDevice device;
  final bool isCurrent;
  final String thisDeviceLabel;
  final String onlineLabel;
  final String offlineLabel;
  final VoidCallback? onTap;

  const CloudDeviceListTile({
    required this.device,
    required this.isCurrent,
    required this.thisDeviceLabel,
    required this.onlineLabel,
    required this.offlineLabel,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isOnline = device.presence == CloudDevicePresence.online;
    final theme = Theme.of(context);
    return CustomListTile(
      icon: Icon(iconDataFor(device.icon), size: 46),
      title: Text(device.displayName, style: const TextStyle(fontSize: 20)),
      subTitle: Row(
        children: [
          _PresenceDot(isOnline: isOnline),
          const SizedBox(width: 8),
          Text(
            isOnline ? onlineLabel : offlineLabel,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      trailing: isCurrent ? _ThisDeviceBadge(label: thisDeviceLabel) : null,
      onTap: onTap,
    );
  }
}

class _PresenceDot extends StatelessWidget {
  final bool isOnline;
  const _PresenceDot({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? Colors.green.shade500 : Theme.of(context).disabledColor;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? color : Colors.transparent,
        border: Border.all(color: color, width: 2),
      ),
    );
  }
}

class _ThisDeviceBadge extends StatelessWidget {
  final String label;
  const _ThisDeviceBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: scheme.onPrimaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
