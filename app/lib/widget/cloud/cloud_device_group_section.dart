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
import 'package:magicshare_app/provider/cloud/auth_provider.dart';
import 'package:magicshare_app/provider/cloud/cloud_bootstrap_service.dart';
import 'package:magicshare_app/provider/cloud/cloud_functions_client_provider.dart';
import 'package:magicshare_app/provider/cloud/presence_heartbeat_service.dart';
import 'package:magicshare_app/provider/settings_provider.dart';
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
    final ref = context.ref;
    final cloudSyncEnabled = ref.watch(settingsProvider.select((s) => s.cloudSyncEnabled));
    final welcomeDismissed = ref.watch(settingsProvider.select((s) => s.cloudWelcomeDismissed));
    final authState = ref.watch(cloudAuthProvider);
    final bootstrapState = ref.watch(cloudBootstrapProvider);
    final accountState = ref.watch(accountRepositoryProvider);

    if (accountState is AccountUnsupported) {
      return const SizedBox.shrink();
    }
    if (!cloudSyncEnabled) {
      return const SizedBox.shrink();
    }

    // Stale-UID detection: if we booted with a cached UID but the cloud
    // bootstrap couldn't complete (the account doesn't exist on the
    // backend, the auth emulator was reset, etc.), treat the session
    // as gone and surface the setup card so the user can pick again.
    final staleSession = bootstrapState is BootstrapFailed && authState is CloudAuthAuthenticated;
    final needsSetup = authState is CloudAuthAwaitingChoice || authState is CloudAuthFailed || staleSession;

    if (needsSetup) {
      return _SetupCard(
        showWelcomeOptions: !welcomeDismissed,
        showSignInError: authState is CloudAuthFailed,
        showStaleSession: staleSession,
      );
    }

    return switch (accountState) {
      AccountUnsupported() => const SizedBox.shrink(),
      AccountIdle() => _LoadingCard(creating: authState is CloudAuthSigningIn),
      AccountLoading() => _LoadingCard(creating: authState is CloudAuthSigningIn),
      AccountReady(:final currentDeviceId, :final devices) => _ReadyCard(
        currentDeviceId: currentDeviceId,
        devices: devices,
      ),
      AccountFailed() => const _FailedCard(),
    };
  }
}

class _LoadingCard extends StatelessWidget {
  final bool creating;
  const _LoadingCard({this.creating = false});

  @override
  Widget build(BuildContext context) {
    final l = t.settingsTab.deviceGroup;
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
            Text(creating ? l.welcome.creating : l.loading),
          ],
        ),
      ),
    );
  }
}

/// Setup card shown when there's no usable cloud session (first launch,
/// post-destroy, or a stale UID after the backend forgot the account).
///
/// Two variants:
/// - [showWelcomeOptions] true: three CTAs — *Create a new group*,
///   *Join an existing group*, *Use without cloud*. The third dismisses
///   the welcome surface for future launches without disabling cloud
///   features; the user can still create / join from settings later.
/// - [showWelcomeOptions] false: two CTAs (no *Use without cloud*).
///   This is what the user sees on subsequent launches once they've
///   dismissed the welcome — settings should always offer a way to
///   set the device group up.
///
/// [showSignInError] adds an inline banner if the last sign-in attempt
/// failed; [showStaleSession] adds a different banner explaining that
/// the previous session is no longer usable so the user knows why
/// they're being prompted to set up again.
class _SetupCard extends StatelessWidget {
  final bool showWelcomeOptions;
  final bool showSignInError;
  final bool showStaleSession;

  const _SetupCard({
    required this.showWelcomeOptions,
    this.showSignInError = false,
    this.showStaleSession = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = t.settingsTab.deviceGroup.welcome;
    final scheme = Theme.of(context).colorScheme;
    return _SectionShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          Text(
            l.title,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(
            l.body,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          if (showStaleSession) ...[
            const SizedBox(height: 12),
            _InfoBanner(
              icon: Icons.history_toggle_off,
              text: l.staleSession,
              tone: _InfoBannerTone.surfaceVariant,
            ),
          ] else if (showSignInError) ...[
            const SizedBox(height: 12),
            _InfoBanner(
              icon: Icons.error_outline,
              text: l.createFailed,
              tone: _InfoBannerTone.error,
            ),
          ],
          const SizedBox(height: 16),
          _SetupAction(
            icon: Icons.add_circle_outline,
            title: showSignInError ? l.retry : l.createNewGroup,
            subtitle: l.createNewGroupHint,
            primary: true,
            onTap: () => _onCreate(context),
          ),
          const SizedBox(height: 8),
          _SetupAction(
            icon: Icons.qr_code_scanner_outlined,
            title: l.joinExistingGroup,
            subtitle: l.joinExistingGroupHint,
            onTap: () => _onJoin(context),
          ),
          if (showWelcomeOptions) ...[
            const SizedBox(height: 8),
            _SetupAction(
              icon: Icons.cloud_off_outlined,
              title: l.useWithoutCloud,
              subtitle: l.useWithoutCloudHint,
              onTap: () => _onUseWithoutCloud(context),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _onCreate(BuildContext context) async {
    final ref = context.ref;
    final auth = ref.notifier(cloudAuthProvider);
    // Stale Authenticated state: discard the dead session before signing
    // in fresh, or signInForNewGroup will treat us as already signed in
    // and no-op.
    if (ref.read(cloudAuthProvider) is CloudAuthAuthenticated) {
      try {
        await auth.deleteAndReset();
      } catch (_) {
        // Best-effort: we still want to attempt the sign-in below.
      }
    }
    await auth.signInForNewGroup();
  }

  void _onJoin(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.settingsTab.deviceGroup.comingSoon)),
    );
  }

  Future<void> _onUseWithoutCloud(BuildContext context) async {
    // Mark the welcome dismissed so the next render drops the third CTA
    // and the section becomes a quieter "set up cloud" prompt. Crucially
    // this does NOT touch settings.cloudSyncEnabled — the user can still
    // create or join a group later from this same section.
    await context.ref.notifier(settingsProvider).setCloudWelcomeDismissed(true);
  }
}

enum _InfoBannerTone { error, surfaceVariant }

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final String text;
  final _InfoBannerTone tone;

  const _InfoBanner({
    required this.icon,
    required this.text,
    required this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (tone) {
      _InfoBannerTone.error => (scheme.errorContainer, scheme.onErrorContainer),
      _InfoBannerTone.surfaceVariant => (scheme.surfaceContainerHighest, scheme.onSurface),
    };
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: foreground, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: foreground, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _SetupAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool primary;
  final VoidCallback onTap;

  const _SetupAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = primary ? scheme.primaryContainer : scheme.surfaceContainerHighest;
    final foreground = primary ? scheme.onPrimaryContainer : scheme.onSurface;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: foreground),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: foreground.withValues(alpha: 0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
      showRefresh: true,
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
  final bool showRefresh;
  const _SectionShell({required this.child, this.showRefresh = false});

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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t.settingsTab.deviceGroup.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (showRefresh) const _RefreshButton(),
                ],
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

/// Section-header icon that re-fetches Firestore device data on tap and
/// pings `updateDevicePresence(online)` so peers see this device as
/// online faster than the 70 s heartbeat would deliver. Visible only
/// when there's an attached account to refresh — i.e. `AccountReady` /
/// `AccountLoading` paths.
class _RefreshButton extends StatefulWidget {
  const _RefreshButton();

  @override
  State<_RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<_RefreshButton> {
  bool _spinning = false;

  Future<void> _onTap() async {
    if (_spinning) return;
    setState(() => _spinning = true);
    final ref = context.ref;
    try {
      // Re-announce online first so other devices see us active before the
      // re-fetch returns. markForeground is internally rate-limited so the
      // common "user smashes the button" case is harmless.
      ref.notifier(presenceHeartbeatProvider).markForeground();
      await ref.notifier(accountRepositoryProvider).refresh();
    } finally {
      if (mounted) setState(() => _spinning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: t.settingsTab.deviceGroup.refresh,
      onPressed: _onTap,
      icon: _spinning
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh, size: 20),
    );
  }
}
