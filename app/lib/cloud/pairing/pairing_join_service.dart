import 'dart:async';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:magicshare_app/cloud/cloud_functions_client.dart';
import 'package:magicshare_app/cloud/crypto/pairing_crypto.dart';
import 'package:magicshare_app/cloud/pairing/lan_reachability.dart';
import 'package:magicshare_app/cloud/pairing/pairing_lan_client.dart';
import 'package:magicshare_app/cloud/pairing/pairing_payload.dart';
import 'package:magicshare_app/model/cloud/cloud_exception.dart';
import 'package:magicshare_app/model/cloud/requests/join_network_new_device.dart';
import 'package:magicshare_app/model/cloud/results/preview_join_token_result.dart';
import 'package:magicshare_app/provider/cloud/auth_provider.dart';
import 'package:magicshare_app/provider/cloud/cloud_functions_client_provider.dart';
import 'package:magicshare_app/provider/cloud/device_identity_service.dart';
import 'package:magicshare_app/provider/cloud/group_key_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('PairingJoinService');

/// Orchestrates the joining-side pairing pipeline. UI calls
/// [previewPairing] to validate LAN reachability and fetch the target
/// group's public-safe device list, then [completePairing] to run the
/// `joinNetwork` → LAN handshake → group-key install → custom-token
/// re-auth → AccountRepository refresh sequence in one shot.
///
/// Two-phase API: the preview is read-only and idempotent (the user
/// can cancel and re-preview), while [completePairing] consumes the
/// join token and is non-idempotent — call it at most once per
/// PairingPayload.
/// Function shape used to probe the issuer's LAN endpoint before
/// consuming the join token. Defaults to [isLanReachable] in
/// production; tests inject a deterministic stub.
typedef LanReachabilityProbe =
    Future<bool> Function({
      required String host,
      required int port,
      Duration timeout,
    });

class PairingJoinService {
  PairingJoinService({
    required this.cloudFunctionsClient,
    required this.authGateway,
    required this.groupKeyService,
    required this.deviceIdentityService,
    required this.lanClient,
    LanReachabilityProbe? lanReachabilityProbe,
  }) : _lanReachabilityProbe = lanReachabilityProbe ?? isLanReachable;

  final CloudFunctionsClient cloudFunctionsClient;
  final CloudAuthGateway authGateway;
  final GroupKeyService groupKeyService;
  final DeviceIdentityService deviceIdentityService;
  final PairingLanClient lanClient;
  final LanReachabilityProbe _lanReachabilityProbe;

  /// Validates that the issuer's LAN endpoint is reachable from this
  /// device, then fetches the target group's public-safe device list.
  /// Read-only — does not consume the join token.
  Future<PairingPreviewOutcome> previewPairing({
    required PairingPayload payload,
    Duration lanProbeTimeout = const Duration(seconds: 2),
  }) async {
    final reachable = await _lanReachabilityProbe(
      host: payload.issuerLanAddress,
      port: payload.issuerLanPort,
      timeout: lanProbeTimeout,
    );
    if (!reachable) return const PairingPreviewLanUnreachable();

    try {
      final preview = await cloudFunctionsClient.previewJoinToken(tokenId: payload.tokenId);
      return PairingPreviewSuccess(preview);
    } on CloudException catch (e) {
      return PairingPreviewCloudFailure(_classifyCloudError(e));
    }
  }

  /// Runs the rest of the pipeline. Caller must have already
  /// previewed (and ideally got user confirmation) before invoking
  /// this. Each stage's failure surfaces a discriminated outcome so
  /// the UI can map to specific localized messages.
  ///
  /// [newDeviceIdentity] is required when the joining device has no
  /// source account doc on its current UID (welcome-card route — no
  /// `createAccount` happened yet). Existing-source-group joiners
  /// can omit it; the backend copies the source device's identity
  /// over instead.
  Future<PairingCompleteOutcome> completePairing({
    required PairingPayload payload,
    JoinNetworkNewDevice? newDeviceIdentity,
  }) async {
    // Sign in anonymously first if not already signed in. We need a
    // valid auth.uid to call joinNetwork. The welcome-card path takes
    // this branch; existing-group-source devices already have one.
    if (authGateway.currentUserId() == null) {
      try {
        await authGateway.signInAnonymously();
      } catch (e, st) {
        _logger.warning('Pre-pair anonymous sign-in failed', e, st);
        return const PairingCompleteAuthFailure();
      }
    }

    // 1. joinNetwork — atomic move + custom token mint.
    final joinerKeys = generatePairingKeyPair();
    final String joiningDeviceId;
    try {
      joiningDeviceId = await deviceIdentityService.ensureDeviceId();
    } catch (e, st) {
      _logger.warning('ensureDeviceId failed', e, st);
      return const PairingCompleteUnknownFailure();
    }

    final String customToken;
    final String newAccountId;
    try {
      final joinResult = await cloudFunctionsClient.joinNetwork(
        tokenId: payload.tokenId,
        deviceId: joiningDeviceId,
        newDevice: newDeviceIdentity,
      );
      customToken = joinResult.customToken;
      newAccountId = joinResult.accountId;
    } on CloudException catch (e) {
      return PairingCompleteCloudFailure(_classifyCloudError(e));
    }

    // 2. LAN handshake — fetch wrapped group key, decrypt, install.
    final Uint8List groupKey;
    try {
      final issuerPubKey = decompressPublicKey(payload.issuerPubKeyCompressed);
      groupKey = await lanClient.exchangeKey(
        issuerHost: payload.issuerLanAddress,
        issuerPort: payload.issuerLanPort,
        tokenId: payload.tokenId,
        joinerPrivateKey: joinerKeys.privateKey,
        joinerPublicKey: joinerKeys.publicKey,
        issuerPublicKey: issuerPubKey,
      );
    } on PairingLanClientException catch (e, st) {
      _logger.warning('LAN handshake failed post-join', e, st);
      return PairingCompleteLanHandshakeFailure(e.error);
    } catch (e, st) {
      _logger.warning('Unexpected LAN handshake failure', e, st);
      return const PairingCompleteUnknownFailure();
    }

    try {
      await groupKeyService.replace(groupKey);
    } catch (e, st) {
      _logger.warning('Group-key install failed', e, st);
      return const PairingCompleteUnknownFailure();
    }

    // 3. Custom-token re-auth so auth.uid switches from the
    // (possibly anon, possibly old-account) UID to the target
    // accountId. AccountRepository's auth-state listener picks this
    // up automatically and re-attaches to the new account path.
    try {
      // Best-effort delete of the old anon user so we don't leave an
      // orphan Firebase Auth record. Failures here aren't fatal —
      // signInWithCustomToken will replace the active session
      // either way.
      try {
        await authGateway.deleteCurrentUser();
      } catch (e) {
        _logger.fine('deleteCurrentUser pre re-auth failed (non-fatal): $e');
      }
      await authGateway.signInWithCustomToken(customToken);
    } catch (e, st) {
      _logger.warning('Custom-token re-auth failed', e, st);
      return const PairingCompleteAuthFailure();
    }

    return PairingCompleteSuccess(newAccountId: newAccountId);
  }

  PairingCloudFailureReason _classifyCloudError(CloudException e) {
    switch (e.code) {
      case CloudErrorCode.notFound:
        return PairingCloudFailureReason.notFound;
      case CloudErrorCode.failedPrecondition:
        return PairingCloudFailureReason.expiredOrConsumed;
      case CloudErrorCode.unauthenticated:
        return PairingCloudFailureReason.unauthorized;
      case CloudErrorCode.invalidArgument:
      case CloudErrorCode.resourceExhausted:
      case CloudErrorCode.unknown:
        return PairingCloudFailureReason.unknown;
    }
  }
}

// ---------------------------------------------------------------------------
// Outcomes
// ---------------------------------------------------------------------------

sealed class PairingPreviewOutcome {
  const PairingPreviewOutcome();
}

class PairingPreviewSuccess extends PairingPreviewOutcome {
  const PairingPreviewSuccess(this.preview);
  final PreviewJoinTokenResult preview;
}

class PairingPreviewLanUnreachable extends PairingPreviewOutcome {
  const PairingPreviewLanUnreachable();
}

class PairingPreviewCloudFailure extends PairingPreviewOutcome {
  const PairingPreviewCloudFailure(this.reason);
  final PairingCloudFailureReason reason;
}

sealed class PairingCompleteOutcome {
  const PairingCompleteOutcome();
}

class PairingCompleteSuccess extends PairingCompleteOutcome {
  const PairingCompleteSuccess({required this.newAccountId});
  final String newAccountId;
}

class PairingCompleteCloudFailure extends PairingCompleteOutcome {
  const PairingCompleteCloudFailure(this.reason);
  final PairingCloudFailureReason reason;
}

class PairingCompleteLanHandshakeFailure extends PairingCompleteOutcome {
  const PairingCompleteLanHandshakeFailure(this.error);
  final PairingLanClientError error;
}

class PairingCompleteAuthFailure extends PairingCompleteOutcome {
  const PairingCompleteAuthFailure();
}

class PairingCompleteUnknownFailure extends PairingCompleteOutcome {
  const PairingCompleteUnknownFailure();
}

enum PairingCloudFailureReason {
  /// Token id not found server-side.
  notFound,

  /// Token expired or already consumed.
  expiredOrConsumed,

  /// Auth or rules check failed.
  unauthorized,

  /// Network or backend currently unreachable.
  networkUnavailable,

  /// Anything else.
  unknown,
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final pairingJoinServiceProvider = Provider<PairingJoinService>((ref) {
  return PairingJoinService(
    cloudFunctionsClient: ref.read(cloudFunctionsClientProvider),
    authGateway: CloudAuthGateway.live(),
    groupKeyService: ref.notifier(groupKeyProvider),
    deviceIdentityService: ref.read(deviceIdentityProvider),
    lanClient: PairingLanClient(),
  );
});
