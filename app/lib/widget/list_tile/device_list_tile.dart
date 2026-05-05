import 'package:common/model/device.dart';
import 'package:flutter/material.dart';
import 'package:magicshare_app/util/device_type_ext.dart';
import 'package:magicshare_app/widget/cloud/presence_dot.dart';
import 'package:magicshare_app/widget/custom_progress_bar.dart';
import 'package:magicshare_app/widget/device_bage.dart';
import 'package:magicshare_app/widget/list_tile/custom_list_tile.dart';

/// Optional cloud-aware presence info for a device tile. When set, the
/// tile renders a presence dot + status label in the subtitle row, and
/// (for offline cloud-only devices) a "Wake" pill. When null, the tile
/// renders exactly as it did before Epic 12.
@immutable
class NetworkPresenceInfo {
  final bool isOnline;
  final String statusLabel;
  final String? wakeLabel;

  const NetworkPresenceInfo({
    required this.isOnline,
    required this.statusLabel,
    this.wakeLabel,
  });
}

class DeviceListTile extends StatelessWidget {
  final Device device;
  final bool isFavorite;

  /// If not null, this name is used instead of [Device.alias].
  /// This is the case when the device is marked as favorite.
  final String? nameOverride;

  final String? info;
  final double? progress;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;

  /// When non-null, the tile shows presence info (dot + status) plus an
  /// optional "Wake" badge. Only set on tiles that represent the user's
  /// own cloud-registered devices (Epic 12 Send-tab merge).
  final NetworkPresenceInfo? networkPresence;

  const DeviceListTile({
    required this.device,
    this.isFavorite = false,
    this.nameOverride,
    this.info,
    this.progress,
    this.onTap,
    this.onFavoriteTap,
    this.networkPresence,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final badgeColor = Color.lerp(theme.colorScheme.secondaryContainer, Colors.white, 0.3)!;
    final wakeBadgeColor = Color.lerp(theme.colorScheme.tertiaryContainer, Colors.white, 0.2)!;
    return CustomListTile(
      icon: Icon(device.deviceType.icon, size: 46),
      title: Text(nameOverride ?? device.alias, style: const TextStyle(fontSize: 20)),
      trailing: onFavoriteTap != null
          ? IconButton(
              icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
              onPressed: onFavoriteTap,
            )
          : null,
      subTitle: Wrap(
        runSpacing: 10,
        spacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (info != null)
            Text(info!, style: const TextStyle(color: Colors.grey))
          else if (progress != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: CustomProgressBar(progress: progress!),
            )
          else ...[
            if (networkPresence != null)
              _PresenceLabel(
                isOnline: networkPresence!.isOnline,
                label: networkPresence!.statusLabel,
              ),
            if (device.ip != null)
              DeviceBadge(
                backgroundColor: badgeColor,
                foregroundColor: theme.colorScheme.onSecondaryContainer,
                label: 'LAN • HTTP',
              )
            else if (networkPresence == null)
              DeviceBadge(
                backgroundColor: badgeColor,
                foregroundColor: theme.colorScheme.onSecondaryContainer,
                label: 'WebRTC',
              ),
            if (device.deviceModel != null)
              DeviceBadge(
                backgroundColor: badgeColor,
                foregroundColor: theme.colorScheme.onSecondaryContainer,
                label: device.deviceModel!,
              ),
            if (networkPresence != null && !networkPresence!.isOnline && networkPresence!.wakeLabel != null)
              DeviceBadge(
                backgroundColor: wakeBadgeColor,
                foregroundColor: theme.colorScheme.onTertiaryContainer,
                label: networkPresence!.wakeLabel!,
              ),
          ],
        ],
      ),
      onTap: onTap,
    );
  }
}

class _PresenceLabel extends StatelessWidget {
  final bool isOnline;
  final String label;
  const _PresenceLabel({required this.isOnline, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PresenceDot(isOnline: isOnline),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
