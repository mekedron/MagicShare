import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:magicshare_app/cloud/pairing/pairing_join_service.dart';
import 'package:magicshare_app/cloud/pairing/pairing_payload.dart';
import 'package:magicshare_app/gen/strings.g.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';
import 'package:magicshare_app/model/cloud/requests/join_network_new_device.dart';
import 'package:magicshare_app/model/cloud/results/preview_join_token_result.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('PairingPreviewDialog');

/// Confirmation dialog shared by both the QR scanner and the manual
/// entry flow. Handles the entire joining-side pipeline post-decode:
/// LAN reachability check → previewJoinToken → user-confirm →
/// completePairing → snackbar on success.
class PairingPreviewDialog extends StatefulWidget {
  const PairingPreviewDialog({
    super.key,
    required this.payload,
    this.newDeviceIdentity,
    this.serviceOverride,
  });

  final PairingPayload payload;

  /// Pass the freshly-built local device identity for the
  /// welcome-card route (joining device has no source account doc).
  /// Existing-source-group joiners can leave this null.
  final JoinNetworkNewDevice? newDeviceIdentity;

  /// Test-only override.
  final PairingJoinService? serviceOverride;

  @override
  State<PairingPreviewDialog> createState() => _PairingPreviewDialogState();
}

class _PairingPreviewDialogState extends State<PairingPreviewDialog> {
  _DialogState _state = const _Loading();
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // ignore: discarded_futures
      _runPreview();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  PairingJoinService get _service => widget.serviceOverride ?? context.ref.read(pairingJoinServiceProvider);

  Future<void> _runPreview() async {
    if (!mounted) return;
    setState(() => _state = const _Loading());
    try {
      final outcome = await _service.previewPairing(payload: widget.payload);
      if (_disposed) return;
      switch (outcome) {
        case PairingPreviewSuccess(:final preview, :final reachableHost):
          setState(() => _state = _Ready(preview: preview, reachableHost: reachableHost));
        case PairingPreviewLanUnreachable():
          setState(() => _state = _Error(t.settingsTab.deviceGroup.pairing.previewDialog.lanUnreachable));
        case PairingPreviewCloudFailure(:final reason):
          setState(() => _state = _Error(_localizeCloudReason(reason)));
      }
    } catch (e, st) {
      _logger.warning('Preview failed', e, st);
      if (_disposed) return;
      setState(() => _state = _Error(t.settingsTab.deviceGroup.pairing.errors.generic));
    }
  }

  Future<void> _onConfirm(_Ready ready) async {
    setState(() => _state = _Joining(preview: ready.preview));
    try {
      final outcome = await _service.completePairing(
        payload: widget.payload,
        newDeviceIdentity: widget.newDeviceIdentity,
        reachableHost: ready.reachableHost,
      );
      if (_disposed || !mounted) return;
      switch (outcome) {
        case PairingCompleteSuccess():
          Navigator.of(context).pop(true);
        case PairingCompleteCloudFailure(:final reason):
          setState(() => _state = _Error(_localizeCloudReason(reason)));
        case PairingCompleteLanHandshakeFailure():
          setState(
            () => _state = _Error(
              t.settingsTab.deviceGroup.pairing.errors.handshakeFailed,
            ),
          );
        case PairingCompleteAuthFailure():
        case PairingCompleteUnknownFailure():
          setState(() => _state = _Error(t.settingsTab.deviceGroup.pairing.errors.generic));
      }
    } catch (e, st) {
      _logger.warning('Complete pairing failed', e, st);
      if (_disposed || !mounted) return;
      setState(() => _state = _Error(t.settingsTab.deviceGroup.pairing.errors.generic));
    }
  }

  String _localizeCloudReason(PairingCloudFailureReason reason) {
    final l = t.settingsTab.deviceGroup.pairing.manualEntryPage.errors;
    switch (reason) {
      case PairingCloudFailureReason.notFound:
        return l.notFound;
      case PairingCloudFailureReason.expiredOrConsumed:
        return l.expired;
      case PairingCloudFailureReason.unauthorized:
      case PairingCloudFailureReason.networkUnavailable:
      case PairingCloudFailureReason.unknown:
        return t.settingsTab.deviceGroup.pairing.errors.generic;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = t.settingsTab.deviceGroup.pairing.previewDialog;
    return AlertDialog(
      scrollable: true,
      title: Text(l.title),
      content: SizedBox(
        width: 360,
        child: switch (_state) {
          _Loading() => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          _Ready(:final preview) => _buildReady(context, preview),
          _Joining() => Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(l.joining),
                ],
              ),
            ),
          ),
          _Error(:final message) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t.general.close),
        ),
        if (_state is _Ready)
          FilledButton(
            onPressed: () => _onConfirm(_state as _Ready),
            child: Text(l.joinButton),
          ),
      ],
    );
  }

  Widget _buildReady(BuildContext context, PreviewJoinTokenResult preview) {
    final l = t.settingsTab.deviceGroup.pairing.previewDialog;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l.body, style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        for (final device in preview.devices) ...[
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(_iconFor(device.icon)),
            title: Text(device.displayName),
            subtitle: Text(_platformLabel(device.platform)),
          ),
        ],
      ],
    );
  }

  IconData _iconFor(CloudDeviceIcon icon) {
    switch (icon) {
      case CloudDeviceIcon.laptop:
        return Icons.laptop_mac;
      case CloudDeviceIcon.desktop:
        return Icons.desktop_windows;
      case CloudDeviceIcon.phone:
        return Icons.smartphone;
      case CloudDeviceIcon.tablet:
        return Icons.tablet_mac;
      case CloudDeviceIcon.server:
        return Icons.dns;
      case CloudDeviceIcon.headless:
        return Icons.terminal;
      case CloudDeviceIcon.other:
        return Icons.devices_other;
    }
  }

  String _platformLabel(CloudDevicePlatform platform) {
    switch (platform) {
      case CloudDevicePlatform.android:
        return 'Android';
      case CloudDevicePlatform.ios:
        return 'iOS';
      case CloudDevicePlatform.macos:
        return 'macOS';
      case CloudDevicePlatform.windows:
        return 'Windows';
      case CloudDevicePlatform.linux:
        return 'Linux';
    }
  }
}

sealed class _DialogState {
  const _DialogState();
}

class _Loading extends _DialogState {
  const _Loading();
}

class _Ready extends _DialogState {
  const _Ready({required this.preview, required this.reachableHost});
  final PreviewJoinTokenResult preview;
  final String reachableHost;
}

class _Joining extends _DialogState {
  const _Joining({required this.preview});
  // ignore: unused_element_parameter
  final PreviewJoinTokenResult preview;
}

class _Error extends _DialogState {
  const _Error(this.message);
  final String message;
}

/// Pushes the dialog and returns `true` on a successful pair.
Future<bool> showPairingPreviewDialog(
  BuildContext context, {
  required PairingPayload payload,
  JoinNetworkNewDevice? newDeviceIdentity,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PairingPreviewDialog(
      payload: payload,
      newDeviceIdentity: newDeviceIdentity,
    ),
  );
  return result ?? false;
}
