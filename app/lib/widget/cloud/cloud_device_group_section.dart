import 'package:flutter/material.dart';
import 'package:magicshare_app/cloud/cloud_functions_client.dart';
import 'package:magicshare_app/config/theme.dart';
import 'package:magicshare_app/gen/strings.g.dart';
import 'package:magicshare_app/model/cloud/cloud_device.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_presence.dart';
import 'package:magicshare_app/model/cloud/cloud_exception.dart';
import 'package:magicshare_app/provider/cloud/account_repository.dart';
import 'package:magicshare_app/provider/cloud/account_reset_service.dart';
import 'package:magicshare_app/provider/cloud/cloud_functions_client_provider.dart';
import 'package:magicshare_app/widget/cloud/cloud_device_detail_sheet.dart';
import 'package:magicshare_app/widget/cloud/cloud_device_list_tile.dart';
import 'package:magicshare_app/widget/dialogs/cloud_device_icon_picker_dialog.dart';
import 'package:magicshare_app/widget/dialogs/cloud_device_leave_dialog.dart';
import 'package:magicshare_app/widget/dialogs/cloud_device_remove_dialog.dart';
import 'package:magicshare_app/widget/dialogs/cloud_device_rename_dialog.dart';
import 'package:magicshare_app/widget/dialogs/delete_device_group_dialog.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Top-of-settings card listing every device in this user's group plus
/// the destructive *Delete this device group* button. Hidden entirely on
/// platforms where Firestore is not supported (Linux today; covered by
/// Epic 16).
class CloudDeviceGroupSection extends StatelessWidget {
  const CloudDeviceGroupSection({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.ref.watch(accountRepositoryProvider);
    return switch (state) {
      AccountUnsupported() => const SizedBox.shrink(),
      AccountIdle() => const _LoadingCard(),
      AccountLoading() => const _LoadingCard(),
      AccountReady(:final currentDeviceId, :final devices) => _ReadyCard(
        currentDeviceId: currentDeviceId,
        devices: devices,
      ),
      AccountFailed() => const _FailedCard(),
    };
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(t.settingsTab.deviceGroup.loading),
          ],
        ),
      ),
    );
  }
}

class _FailedCard extends StatelessWidget {
  const _FailedCard();

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(t.settingsTab.deviceGroup.loadFailed),
      ),
    );
  }
}

class _ReadyCard extends StatelessWidget {
  final String currentDeviceId;
  final List<CloudDevice> devices;

  const _ReadyCard({
    required this.currentDeviceId,
    required this.devices,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = _sortedDevices(devices, currentDeviceId);
    return _SectionShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final device in sorted) ...[
            const SizedBox(height: 8),
            CloudDeviceListTile(
              device: device,
              isCurrent: device.deviceId == currentDeviceId,
              thisDeviceLabel: t.settingsTab.deviceGroup.thisDevice,
              onlineLabel: t.settingsTab.deviceGroup.presenceOnline,
              offlineLabel: t.settingsTab.deviceGroup.presenceOffline,
              onTap: () => _onDeviceTap(context, device),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.qr_code_2_outlined),
                  label: Text(t.settingsTab.deviceGroup.inviteDevice),
                  onPressed: () => _showComingSoon(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.qr_code_scanner_outlined),
                  label: Text(t.settingsTab.deviceGroup.joinExistingGroup),
                  onPressed: () => _showComingSoon(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.warning,
            ),
            icon: const Icon(Icons.delete_forever_outlined),
            label: Text(t.settingsTab.deviceGroup.deleteGroup),
            onPressed: () => _onDeleteGroup(context),
          ),
        ],
      ),
    );
  }

  Future<void> _onDeviceTap(BuildContext context, CloudDevice device) async {
    final isCurrent = device.deviceId == currentDeviceId;
    final action = await showModalBottomSheet<CloudDeviceAction>(
      context: context,
      showDragHandle: true,
      builder: (_) => CloudDeviceDetailSheet(
        deviceName: device.displayName,
        isCurrent: isCurrent,
      ),
    );
    if (action == null || !context.mounted) return;
    final ref = context.ref;
    final client = ref.read(cloudFunctionsClientProvider);

    switch (action) {
      case CloudDeviceAction.rename:
        await _runRename(context, client, device);
      case CloudDeviceAction.changeIcon:
        await _runChangeIcon(context, client, device);
      case CloudDeviceAction.removeFromGroup:
        await _runRemove(context, client, device);
      case CloudDeviceAction.leaveOrDestroy:
        await _runLeave(context, ref.read(accountResetServiceProvider), device);
    }
  }

  Future<void> _runRename(
    BuildContext context,
    CloudFunctionsClient client,
    CloudDevice device,
  ) async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => CloudDeviceRenameDialog(initialName: device.displayName),
    );
    if (newName == null || newName == device.displayName || !context.mounted) return;
    try {
      await client.renameDevice(deviceId: device.deviceId, displayName: newName);
      if (!context.mounted) return;
      _showSnack(context, t.settingsTab.deviceGroup.snackbars.renamed);
    } on CloudException {
      if (!context.mounted) return;
      _showError(context);
    }
  }

  Future<void> _runChangeIcon(
    BuildContext context,
    CloudFunctionsClient client,
    CloudDevice device,
  ) async {
    final picked = await showDialog<CloudDeviceIcon>(
      context: context,
      builder: (_) => CloudDeviceIconPickerDialog(current: device.icon),
    );
    if (picked == null || picked == device.icon || !context.mounted) return;
    try {
      await client.setDeviceIcon(deviceId: device.deviceId, icon: picked);
      if (!context.mounted) return;
      _showSnack(context, t.settingsTab.deviceGroup.snackbars.iconUpdated);
    } on CloudException {
      if (!context.mounted) return;
      _showError(context);
    }
  }

  Future<void> _runRemove(
    BuildContext context,
    CloudFunctionsClient client,
    CloudDevice device,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => CloudDeviceRemoveDialog(deviceName: device.displayName),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await client.removeDevice(deviceId: device.deviceId);
      if (!context.mounted) return;
      _showSnack(context, t.settingsTab.deviceGroup.snackbars.removed);
    } on CloudException {
      if (!context.mounted) return;
      _showError(context);
    }
  }

  Future<void> _runLeave(
    BuildContext context,
    AccountResetService reset,
    CloudDevice device,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const CloudDeviceLeaveDialog(),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await reset.resetForLeaveGroup(currentDeviceId: device.deviceId);
      if (!context.mounted) return;
      _showSnack(context, t.settingsTab.deviceGroup.snackbars.groupDeleted);
    } on CloudException {
      if (!context.mounted) return;
      _showError(context);
    } catch (_) {
      if (!context.mounted) return;
      _showError(context);
    }
  }

  Future<void> _onDeleteGroup(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const DeleteDeviceGroupDialog(),
    );
    if (confirmed != true || !context.mounted) return;
    final reset = context.ref.read(accountResetServiceProvider);
    try {
      await reset.resetForGroupDeletion();
      if (!context.mounted) return;
      _showSnack(context, t.settingsTab.deviceGroup.snackbars.groupDeleted);
    } on CloudException {
      if (!context.mounted) return;
      _showError(context);
    } catch (_) {
      if (!context.mounted) return;
      _showError(context);
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.settingsTab.deviceGroup.errors.generic)),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.settingsTab.deviceGroup.comingSoon)),
    );
  }
}

/// Sorted: current device first, then online by name (case-insensitive),
/// then offline by name. Visible for testing.
@visibleForTesting
List<CloudDevice> sortDevicesForSection(List<CloudDevice> devices, String currentDeviceId) {
  return _sortedDevices(devices, currentDeviceId);
}

List<CloudDevice> _sortedDevices(List<CloudDevice> devices, String currentDeviceId) {
  final list = [...devices];
  list.sort((a, b) {
    final aCurrent = a.deviceId == currentDeviceId;
    final bCurrent = b.deviceId == currentDeviceId;
    if (aCurrent != bCurrent) return aCurrent ? -1 : 1;
    final aOnline = a.presence == CloudDevicePresence.online;
    final bOnline = b.presence == CloudDevicePresence.online;
    if (aOnline != bOnline) return aOnline ? -1 : 1;
    return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
  });
  return list;
}

class _SectionShell extends StatelessWidget {
  final Widget child;
  const _SectionShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.settingsTab.deviceGroup.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
