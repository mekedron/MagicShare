import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:common/model/device.dart';
import 'package:common/model/file_type.dart';
import 'package:common/model/session_status.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:magicshare_app/cloud/wake/link_payload.dart';
import 'package:magicshare_app/cloud/wake/link_payload_codec.dart';
import 'package:magicshare_app/gen/strings.g.dart';
import 'package:magicshare_app/model/cloud/cloud_device.dart';
import 'package:magicshare_app/model/cloud/cloud_exception.dart';
import 'package:magicshare_app/model/cloud/requests/send_link_notification_request.dart';
import 'package:magicshare_app/model/cross_file.dart';
import 'package:magicshare_app/model/persistence/favorite_device.dart';
import 'package:magicshare_app/model/send_mode.dart';
import 'package:magicshare_app/pages/progress_page.dart';
import 'package:magicshare_app/pages/send_page.dart';
import 'package:magicshare_app/pages/web_send_page.dart';
import 'package:magicshare_app/provider/cloud/account_repository.dart';
import 'package:magicshare_app/provider/cloud/cloud_functions_client_provider.dart';
import 'package:magicshare_app/provider/cloud/group_key_provider.dart';
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

final _sendTabLogger = Logger('SendTab');

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
          await ref.redux(favoritesProvider).dispatchAsync(RemoveFavoriteAction(deviceFingerprint: device.fingerprint));
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

      // URL fast-path: when the only thing being sent is a single
      // http(s) URL and the target is one of the user's own cloud
      // devices, skip P2P entirely and ride the FCM link-notification
      // channel instead. Falls through to the LAN flow on any miss
      // (multiple files, non-URL text, non-cloud target).
      final url = _singleUrlPayload(selectedFiles);
      final mergedTarget = url == null ? null : _findMergedByFingerprint(networkDevices, device.fingerprint);
      if (url != null && mergedTarget?.cloud != null) {
        await _dispatchUrlFastPath(
          context: context,
          ref: ref,
          target: mergedTarget!.cloud!,
          url: url,
        );
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
      final session = ref.read(sendProvider).values.firstWhereOrNull((s) => s.target.ip == device.ip);
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
    final devices = ref.read(nearbyDevicesProvider).devices;
    if (devices.isEmpty) {
      await dispatchAsync(StartSmartScan(forceLegacy: false));
    }
  }
}

/// Returns the URL when [files] is exactly one text-mode CrossFile whose
/// content is a valid http(s) URI; null otherwise. Whitespace-only or
/// quote-wrapped URLs intentionally don't match — we'd rather fall back
/// to the regular flow than guess at user intent.
String? _singleUrlPayload(List<CrossFile> files) {
  if (files.length != 1) return null;
  final f = files.single;
  if (f.fileType != FileType.text) return null;
  final bytes = f.bytes;
  if (bytes == null) return null;
  final text = utf8.decode(bytes, allowMalformed: false);
  if (text != text.trim()) return null;
  if (text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (uri.host.isEmpty) return null;
  return text;
}

MergedDevice? _findMergedByFingerprint(List<MergedDevice> devices, String fingerprint) {
  if (fingerprint.isEmpty) return null;
  for (final m in devices) {
    if (m.displayDevice.fingerprint == fingerprint) return m;
  }
  return null;
}

Future<void> _dispatchUrlFastPath({
  required BuildContext context,
  required Ref ref,
  required CloudDevice target,
  required String url,
}) async {
  _sendTabLogger.info(
    'URL fast-path: target=${target.deviceId} (${target.displayName}, '
    'fcmToken=${target.fcmToken == null ? 'null' : 'set'}, '
    'platform=${target.platform.name})',
  );
  final accountState = ref.read(accountRepositoryProvider);
  if (accountState is! AccountReady) {
    _sendTabLogger.warning('Cloud not ready (accountState=${accountState.runtimeType})');
    _showLinkError(context, 'Cloud not ready');
    return;
  }
  final encryptMode = ref.read(settingsProvider).encryptLinkNotifications;
  _sendTabLogger.info('Link mode: ${encryptMode ? 'encrypted' : 'plaintext'}');
  final client = ref.read(cloudFunctionsClientProvider);

  late SendLinkNotificationRequest request;
  if (encryptMode) {
    final keyState = ref.read(groupKeyProvider);
    if (keyState is! GroupKeyReady) {
      _sendTabLogger.warning(
        'Encrypted link mode but group key not loaded '
        '(state=${keyState.runtimeType}, accountState=${accountState.runtimeType})',
      );
      _showLinkError(
        context,
        'Group key missing on this device — open Settings → Device group → '
        'Delete this device group, then create or join a group again.',
      );
      return;
    }
    final encoded = encodeLinkPayload(LinkPayload(url: url), keyState.key);
    request = EncryptedLinkNotificationRequest(
      sourceDeviceId: accountState.currentDeviceId,
      targetDeviceId: target.deviceId,
      payload: encoded,
    );
  } else {
    request = PlaintextLinkNotificationRequest(
      sourceDeviceId: accountState.currentDeviceId,
      targetDeviceId: target.deviceId,
      url: url,
    );
  }

  try {
    final result = await client.sendLinkNotification(request);
    _sendTabLogger.info(
      'sendLinkNotification returned: delivered=${result.delivered}, channel=${result.channel}',
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.sendTab.linkSent(device: target.displayName))),
    );
  } on CloudException catch (e) {
    _sendTabLogger.warning(
      'sendLinkNotification CloudException: code=${e.code.name} '
      'message="${e.message}" details=${e.details}',
    );
    if (!context.mounted) return;
    // The default e.message for an `internal` Firebase Functions error is
    // a useless "An internal error has occurred…". Surface the code too
    // so the user (and the run log) has something to act on.
    final reason = e.code.name == 'internal' ? '${e.message} (code=${e.code.name})' : e.message;
    _showLinkError(context, reason);
  }
}

void _showLinkError(BuildContext context, String reason) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(t.sendTab.linkSendFailed(reason: reason))),
  );
}
