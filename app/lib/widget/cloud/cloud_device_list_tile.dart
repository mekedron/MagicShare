import 'package:flutter/material.dart';
import 'package:magicshare_app/model/cloud/cloud_device.dart';
import 'package:magicshare_app/provider/cloud/merged_network_devices_provider.dart';
import 'package:magicshare_app/widget/cloud/cloud_device_icon_data.dart';
import 'package:magicshare_app/widget/cloud/presence_dot.dart';
import 'package:magicshare_app/widget/list_tile/custom_list_tile.dart';

/// Renders a single device row in the device-group settings section.
/// Takes a [MergedDevice] so the same predicate that drives the Send
/// tab dot drives the settings page dot — no parallel "is this in the
/// LAN list" recomputation.
///
/// Pure presentation: all label strings are passed in so the widget
/// itself stays free of localization lookups (and easy to widget-test
/// in any locale).
class CloudDeviceListTile extends StatelessWidget {
  final MergedDevice merged;
  final bool isCurrent;
  final String thisDeviceLabel;
  final String onlineLabel;
  final String offlineLabel;
  final VoidCallback? onTap;

  const CloudDeviceListTile({
    required this.merged,
    required this.isCurrent,
    required this.thisDeviceLabel,
    required this.onlineLabel,
    required this.offlineLabel,
    this.onTap,
    super.key,
  });

  CloudDevice get _cloud => merged.cloud!;

  @override
  Widget build(BuildContext context) {
    // The current-device row can't appear in our own LAN list (we
    // filter out our own multicast announces), so [merged.isOnline]
    // would be false even when the process is alive. Special-case it
    // and show Online whenever our cloud heartbeat is fresh.
    final isOnline = isCurrent ? cloudDeviceIsOnline(_cloud) : merged.isOnline;
    final theme = Theme.of(context);
    return CustomListTile(
      icon: Icon(iconDataFor(_cloud.icon), size: 46),
      title: Text(_cloud.displayName, style: const TextStyle(fontSize: 20)),
      subTitle: Row(
        children: [
          PresenceDot(isOnline: isOnline),
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
