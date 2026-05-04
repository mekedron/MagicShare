import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:magicshare_app/cloud/cloud_functions_client.dart';
import 'package:magicshare_app/cloud/crypto/pairing_crypto.dart';
import 'package:magicshare_app/cloud/pairing/pairing_lan_server.dart';
import 'package:magicshare_app/cloud/pairing/pairing_payload.dart';
import 'package:magicshare_app/gen/strings.g.dart';
import 'package:magicshare_app/model/cloud/cloud_exception.dart';
import 'package:magicshare_app/provider/cloud/account_repository.dart';
import 'package:magicshare_app/provider/cloud/cloud_functions_client_provider.dart';
import 'package:magicshare_app/provider/cloud/group_key_provider.dart';
import 'package:magicshare_app/provider/local_ip_provider.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('InviteDeviceDialog');

/// Factory used by the dialog to spin up the LAN-side handshake
/// server. Defaults to [PairingLanServer.new]; widget tests inject a
/// fake [PairingLanServerHandle] implementation to drive the
/// lifecycle deterministically without binding a real socket.
typedef PairingLanServerFactory =
    PairingLanServerHandle Function({
      required String tokenId,
      required dynamic issuerPrivateKey,
      required Uint8List groupKey,
    });

PairingLanServerHandle _defaultServerFactory({
  required String tokenId,
  required dynamic issuerPrivateKey,
  required Uint8List groupKey,
}) {
  return PairingLanServer(
    tokenId: tokenId,
    // The factory uses dynamic to keep the signature widget-test
    // friendly; the production path always supplies an ECPrivateKey.
    issuerPrivateKey: issuerPrivateKey,
    groupKey: groupKey,
  );
}

/// Issuing-side pairing dialog. Mints a join token, spins up an
/// ephemeral LAN listener, renders the resulting payload as both a
/// QR code and a typeable Crockford-Base32 manual code, and listens
/// for the joiner to complete the handshake.
///
/// Lifecycle is intentionally tied to the dialog: closing the dialog
/// (via the close button, by tapping outside, or by Navigator.pop)
/// tears the LAN server down so the port is released. Auto-refresh
/// when the token expires re-mints with a fresh keypair so an
/// attacker who saw the previous QR can't race a stale handshake.
class InviteDeviceDialog extends StatefulWidget {
  const InviteDeviceDialog({
    super.key,
    this.cloudFunctionsClient,
    this.lanServerFactory,
    this.currentDeviceIdOverride,
    this.lanAddressOverride,
    this.groupKeyOverride,
    this.now = _systemNow,
  });

  /// Test override; in production the dialog reads from refena.
  final CloudFunctionsClient? cloudFunctionsClient;

  /// Test override; in production [PairingLanServer.new] is used.
  final PairingLanServerFactory? lanServerFactory;

  /// Test override.
  final String? currentDeviceIdOverride;

  /// Test override; in production read from `localIpProvider`.
  final String? lanAddressOverride;

  /// Test override; in production read from `groupKeyProvider`.
  final Uint8List? groupKeyOverride;

  /// Test override for the wall clock used by the countdown.
  final DateTime Function() now;

  @override
  State<InviteDeviceDialog> createState() => _InviteDeviceDialogState();
}

class _InviteDeviceDialogState extends State<InviteDeviceDialog> {
  _SessionState _session = const _SessionLoading();
  Timer? _countdownTicker;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    // Defer to post-frame so refena reads see a fully-built widget tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_startSession());
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _countdownTicker?.cancel();
    final session = _session;
    if (session is _SessionReady) {
      unawaited(session.lanServer.stop());
    }
    super.dispose();
  }

  Future<void> _startSession() async {
    if (_disposed) return;
    setState(() => _session = const _SessionLoading());

    try {
      // Resolve every dependency from constructor overrides first;
      // fall back to refena only when an override is missing. This
      // lets widget tests pump the dialog without a RefenaScope at
      // all, which is the cleanest way to keep the test surface
      // small.
      final clientOverride = widget.cloudFunctionsClient;
      final currentDeviceIdOverride = widget.currentDeviceIdOverride;
      final lanAddressOverride = widget.lanAddressOverride;
      final groupKeyOverride = widget.groupKeyOverride;

      final allOverridden = clientOverride != null && currentDeviceIdOverride != null && lanAddressOverride != null && groupKeyOverride != null;

      final CloudFunctionsClient client;
      final String? currentDeviceId;
      final String? lanAddress;
      final Uint8List? groupKey;

      if (allOverridden) {
        client = clientOverride;
        currentDeviceId = currentDeviceIdOverride;
        lanAddress = lanAddressOverride;
        groupKey = groupKeyOverride;
      } else {
        final ref = context.ref;
        client = clientOverride ?? ref.read(cloudFunctionsClientProvider);
        currentDeviceId = currentDeviceIdOverride ?? _readCurrentDeviceId(ref);
        lanAddress = lanAddressOverride ?? _readPrimaryLanIp(ref);
        groupKey = groupKeyOverride ?? _readGroupKey(ref);
      }

      if (currentDeviceId == null || currentDeviceId.isEmpty) {
        setState(
          () => _session = _SessionError(t.settingsTab.deviceGroup.pairing.errors.generic),
        );
        return;
      }
      if (lanAddress == null) {
        setState(
          () => _session = _SessionError(t.settingsTab.deviceGroup.pairing.errors.noLan),
        );
        return;
      }
      if (groupKey == null) {
        setState(
          () => _session = _SessionError(t.settingsTab.deviceGroup.pairing.errors.generic),
        );
        return;
      }

      final keypair = generatePairingKeyPair();
      // Mint the cloud-side token first so we can hand the
      // authoritative token id to the LAN server on construction.
      final tokenResult = await client.createJoinToken(issuingDeviceId: currentDeviceId);
      if (_disposed) return;

      final realServer = (widget.lanServerFactory ?? _defaultServerFactory)(
        tokenId: tokenResult.tokenId,
        issuerPrivateKey: keypair.privateKey,
        groupKey: groupKey,
      );
      final port = await realServer.start();

      final payload = PairingPayload(
        tokenId: tokenResult.tokenId,
        issuerLanAddress: lanAddress,
        issuerLanPort: port,
        issuerPubKeyCompressed: compressPublicKey(keypair.publicKey),
      );

      final session = _SessionReady(
        payload: payload,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(tokenResult.expiresAtMs),
        lanServer: realServer,
      );
      if (!mounted || _disposed) {
        unawaited(realServer.stop());
        return;
      }
      setState(() => _session = session);
      _startCountdownTicker();
      _listenForHandshake(session);
    } on CloudException catch (e, st) {
      _logger.warning('createJoinToken failed', e, st);
      if (!mounted || _disposed) return;
      setState(
        () => _session = _SessionError(t.settingsTab.deviceGroup.pairing.errors.generic),
      );
    } catch (e, st) {
      _logger.warning('Pairing session start failed', e, st);
      if (!mounted || _disposed) return;
      setState(
        () => _session = _SessionError(t.settingsTab.deviceGroup.pairing.errors.generic),
      );
    }
  }

  String? _readCurrentDeviceId(Ref ref) {
    final accountState = ref.read(accountRepositoryProvider);
    return switch (accountState) {
      AccountReady(:final currentDeviceId) => currentDeviceId,
      AccountLoading(:final currentDeviceId) => currentDeviceId.isEmpty ? null : currentDeviceId,
      _ => null,
    };
  }

  String? _readPrimaryLanIp(Ref ref) {
    final ips = ref.read(localIpProvider).localIps;
    return ips.isEmpty ? null : ips.first;
  }

  Uint8List? _readGroupKey(Ref ref) {
    final state = ref.read(groupKeyProvider);
    return state is GroupKeyReady ? state.key : null;
  }

  void _startCountdownTicker() {
    _countdownTicker?.cancel();
    _countdownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final session = _session;
      if (session is! _SessionReady) return;
      final remaining = session.expiresAt.difference(widget.now());
      if (remaining.inSeconds <= 0) {
        _countdownTicker?.cancel();
        // Token expired while the dialog was open — re-mint
        // automatically so a user who left it open still sees a
        // valid code.
        unawaited(_startSession());
      } else {
        // Force a rebuild so the countdown text updates.
        setState(() {});
      }
    });
  }

  void _listenForHandshake(_SessionReady session) {
    unawaited(
      session.lanServer.handshakeCompleted.then(
        (_) {
          if (!mounted || _disposed) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.settingsTab.deviceGroup.pairing.inviteDialog.successPaired)),
          );
          Navigator.of(context).pop();
        },
        onError: (Object e) {
          if (!mounted || _disposed) return;
          // Timeout — the token expired without a successful handshake.
          // Auto-refresh kicks in via _startCountdownTicker; nothing to
          // do here other than swallow the error.
          _logger.fine('LAN server handshake error: $e');
        },
      ),
    );
  }

  Future<void> _onCopyManualCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t.settingsTab.deviceGroup.pairing.inviteDialog.copied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = t.settingsTab.deviceGroup.pairing.inviteDialog;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(l.title),
      scrollable: true,
      content: SizedBox(
        width: 360,
        child: switch (_session) {
          _SessionLoading() => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
          _SessionError(:final message) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(message, style: TextStyle(color: scheme.error)),
          ),
          _SessionReady(:final payload, :final expiresAt) => _buildReady(
            context,
            payload: payload,
            expiresAt: expiresAt,
          ),
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.general.close),
        ),
      ],
    );
  }

  Widget _buildReady(
    BuildContext context, {
    required PairingPayload payload,
    required DateTime expiresAt,
  }) {
    final l = t.settingsTab.deviceGroup.pairing.inviteDialog;
    final scheme = Theme.of(context).colorScheme;
    final qrData = encodePairingUri(payload);
    final manualCode = encodePairingManualCode(payload);
    final remaining = expiresAt.difference(widget.now());

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.subtitle,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 220,
          height: 220,
          child: PrettyQrView.data(
            data: qrData,
            errorCorrectLevel: QrErrorCorrectLevel.L,
            decoration: PrettyQrDecoration(
              shape: PrettyQrSmoothSymbol(roundFactor: 0, color: scheme.onSurface),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(l.manualCodeLabel, style: TextStyle(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            manualCode,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                remaining.inSeconds <= 0 ? l.expired : l.expiresIn(seconds: remaining.inSeconds),
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ),
            TextButton.icon(
              onPressed: () => unawaited(_onCopyManualCode(manualCode)),
              icon: const Icon(Icons.copy, size: 16),
              label: Text(l.copyCode),
            ),
          ],
        ),
      ],
    );
  }
}

sealed class _SessionState {
  const _SessionState();
}

class _SessionLoading extends _SessionState {
  const _SessionLoading();
}

class _SessionError extends _SessionState {
  const _SessionError(this.message);
  final String message;
}

class _SessionReady extends _SessionState {
  const _SessionReady({
    required this.payload,
    required this.expiresAt,
    required this.lanServer,
  });
  final PairingPayload payload;
  final DateTime expiresAt;
  final PairingLanServerHandle lanServer;
}

DateTime _systemNow() => DateTime.now();
