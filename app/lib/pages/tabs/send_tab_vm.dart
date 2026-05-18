import 'package:collection/collection.dart';
import 'package:common/model/device.dart';
import 'package:common/model/session_status.dart';
import 'package:flutter/material.dart';
import 'package:magicshare_app/model/cloud/cloud_device.dart';
import 'package:magicshare_app/model/cross_file.dart';
import 'package:magicshare_app/model/persistence/favorite_device.dart';
import 'package:magicshare_app/model/send_mode.dart';
import 'package:magicshare_app/model/state/nearby_devices_state.dart';
import 'package:magicshare_app/pages/progress_page.dart';
import 'package:magicshare_app/pages/send_page.dart';
import 'package:magicshare_app/pages/web_send_page.dart';
import 'package:magicshare_app/provider/cloud/merged_network_devices_provider.dart';
import 'package:magicshare_app/provider/cloud/wake_orchestrator.dart';
import 'package:magicshare_app/provider/favorites_provider.dart';
import 'package:magicshare_app/provider/local_ip_provider.dart';
import 'package:magicshare_app/provider/network/nearby_devices_provider.dart';
import 'package:magicshare_app/provider/network/scan_facade.dart';
import 'package:magicshare_app/provider/network/send_provider.dart';
import 'package:magicshare_app/provider/selection/selected_sending_files_provider.dart';
import 'package:magicshare_app/provider/settings_provider.dart';
import 'package:magicshare_app/util/favorites.dart';
import 'package:magicshare_app/widget/dialogs/address_input_dialog.dart';
import 'package:magicshare_app/widget/dialogs/favorite_delete_dialog.dart';
import 'package:magicshare_app/widget/dialogs/favorite_dialog.dart';
import 'package:magicshare_app/widget/dialogs/favorite_edit_dialog.dart';
import 'package:magicshare_app/widget/dialogs/no_files_dialog.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class SendTabVm {
  final SendMode sendMode;
  final List<CrossFile> selectedFiles;
  final List<String> localIps;
  final List<MergedDevice> networkDevices;
  final List<FavoriteDevice> favoriteDevices;
  final Map<String, WakeStatus> wakeStatuses;
  final Future<void> Function(BuildContext context) onTapAddress;
  final Future<void> Function(BuildContext context) onTapFavorite;
  final Future<void> Function(BuildContext context, SendMode mode) onTapSendMode;
  final Future<void> Function(BuildContext context, Device device) onToggleFavorite;
  final Future<void> Function(BuildContext context, Device device) onTapDevice;
  final Future<void> Function(BuildContext context, Device device) onTapDeviceMultiSend;
  final Future<void> Function(BuildContext context, CloudDevice target) onTapWakeDevice;
  final void Function(String targetDeviceId) onClearWakeError;

  const SendTabVm({
    required this.sendMode,
    required this.selectedFiles,
    required this.localIps,
    required this.networkDevices,
    required this.favoriteDevices,
    required this.wakeStatuses,
    required this.onTapAddress,
    required this.onTapFavorite,
    required this.onTapSendMode,
    required this.onToggleFavorite,
    required this.onTapDevice,
    required this.onTapDeviceMultiSend,
    required this.onTapWakeDevice,
    required this.onClearWakeError,
  });
}

final sendTabVmProvider = ViewProvider((ref) {
  final sendMode = ref.watch(settingsProvider.select((s) => s.sendMode));
  final selectedFiles = ref.watch(selectedSendingFilesProvider);
  final localIps = ref.watch(localIpProvider).localIps;
  final networkDevices = ref.watch(mergedNetworkDevicesProvider);
  final favoriteDevices = ref.watch(favoritesProvider);
  final wakeStatuses = ref.watch(wakeOrchestratorProvider);

  return SendTabVm(
    sendMode: sendMode,
    selectedFiles: selectedFiles,
    localIps: localIps,
    networkDevices: networkDevices,
    favoriteDevices: favoriteDevices,
    wakeStatuses: wakeStatuses,
    onTapAddress: (context) async {
      final files = ref.read(selectedSendingFilesProvider);
      if (files.isEmpty) {
        await context.pushBottomSheet(() => const NoFilesDialog());
        return;
      }
      final device = await showDialog<Device?>(
        context: context,
        builder: (_) => const AddressInputDialog(),
      );
      if (device != null && context.mounted) {
        await ref
            .notifier(sendProvider)
            .startSession(
              target: device,
              files: files,
              background: false,
            );
      }
    },
    onTapFavorite: (context) async {
      final device = await showDialog<Device?>(
        context: context,
        builder: (_) => const FavoritesDialog(),
      );
      if (device != null && context.mounted) {
        final files = ref.read(selectedSendingFilesProvider);
        if (files.isEmpty) {
          await context.pushBottomSheet(() => const NoFilesDialog());
          return;
        }

        await ref
            .notifier(sendProvider)
            .startSession(
              target: device,
              files: files,
              background: false,
            );
      }
    },
    onTapSendMode: (context, mode) async {
      if (mode == SendMode.link) {
        final files = ref.read(selectedSendingFilesProvider);
        if (files.isEmpty) {
          await context.pushBottomSheet(() => const NoFilesDialog());
          return;
        }
        await context.push(() => WebSendPage(files));
        return;
      }

      await ref.notifier(settingsProvider).setSendMode(mode);
      if (mode != SendMode.multiple) {
        ref.notifier(sendProvider).clearAllSessions();
      }
    },
    onToggleFavorite: (context, device) async {
      final favoriteDevice = favoriteDevices.findDevice(device);
      if (favoriteDevice != null) {
        final result = await showDialog<bool>(
          context: context,
          builder: (_) => FavoriteDeleteDialog(favoriteDevice),
        );
        if (result == true) {
          await ref.redux(favoritesProvider).dispatchAsync(RemoveFavoriteAction(deviceFingerprint: favoriteDevice.fingerprint));
        }
      } else {
        await showDialog(
          context: context,
          builder: (_) => FavoriteEditDialog(prefilledDevice: device),
        );
      }
    },
    onTapDevice: (context, device) async {
      if (selectedFiles.isEmpty) {
        await context.pushBottomSheet(() => const NoFilesDialog());
        return;
      }

      await ref
          .notifier(sendProvider)
          .startSession(
            target: device,
            files: selectedFiles,
            background: false,
          );
    },
    onTapDeviceMultiSend: (context, device) async {
      final deviceIp = device.firstHttpEndpoint?.ip;
      final session = deviceIp == null
          ? null
          : ref
                .read(sendProvider)
                .values
                .firstWhereOrNull(
                  (s) => s.target.firstHttpEndpoint?.ip == deviceIp,
                );
      if (session != null) {
        if (session.status == SessionStatus.waiting) {
          ref.notifier(sendProvider).setBackground(session.sessionId, false);
          await context.push(
            () => SendPage(showAppBar: true, closeSessionOnClose: false, sessionId: session.sessionId),
            transition: RouterinoTransition.fade(),
          );
          ref.notifier(sendProvider).setBackground(session.sessionId, true);
          return;
        } else if (session.status == SessionStatus.sending || session.status == SessionStatus.finishedWithErrors) {
          ref.notifier(sendProvider).setBackground(session.sessionId, false);
          await context.push(() => ProgressPage(showAppBar: true, closeSessionOnClose: false, sessionId: session.sessionId));
          ref.notifier(sendProvider).setBackground(session.sessionId, true);
          return;
        }
      }

      final files = ref.read(selectedSendingFilesProvider);
      if (files.isEmpty) {
        await context.pushBottomSheet(() => const NoFilesDialog());
        return;
      }

      if (session != null) {
        // close old session
        ref.notifier(sendProvider).closeSession(session.sessionId);
      }

      await ref
          .notifier(sendProvider)
          .startSession(
            target: device,
            files: files,
            background: true,
          );
    },
    onTapWakeDevice: (context, target) async {
      final files = ref.read(selectedSendingFilesProvider);
      if (files.isEmpty) {
        await context.pushBottomSheet(() => const NoFilesDialog());
        return;
      }
      await ref
          .notifier(wakeOrchestratorProvider)
          .start(
            target: target,
            files: files,
            background: false,
          );
    },
    onClearWakeError: (targetDeviceId) {
      ref.notifier(wakeOrchestratorProvider).clearError(targetDeviceId);
    },
  );
});

class SendTabInitAction extends AsyncGlobalAction {
  final BuildContext context;

  SendTabInitAction(this.context);

  @override
  Future<void> reduce() async {
    final state = ref.read(nearbyDevicesProvider);
    final devices = state.devices;
    // Force a fresh subnet scan when we have a signaling-discovered device
    // that lacks an HTTP twin — the signaling server can find peers faster
    // than the LAN handshake (or before the peer's HTTPS server is up), so
    // the merged list would otherwise be stuck on "WebRTC only" and the
    // send-via-HTTP path would abort.
    if (devices.isEmpty || _hasSignalingWithoutLanMatch(state)) {
      await dispatchAsync(StartSmartScan(forceLegacy: false));
    }
  }

  bool _hasSignalingWithoutLanMatch(NearbyDevicesState state) {
    for (final group in state.signalingDevices.values) {
      for (final sigDev in group) {
        final hasLanTwin = state.devices.values.any(
          (lanDev) => lanDev.alias == sigDev.alias && lanDev.deviceModel == sigDev.deviceModel && lanDev.deviceType == sigDev.deviceType,
        );
        if (!hasLanTwin) {
          return true;
        }
      }
    }
    return false;
  }
}
