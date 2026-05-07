import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:magicshare_app/config/cloud/firebase_init.dart';
import 'package:magicshare_app/model/cloud/cloud_device_icon.dart';
import 'package:magicshare_app/model/cloud/cloud_device_platform.dart';
import 'package:magicshare_app/model/cloud/cloud_exception.dart';
import 'package:magicshare_app/model/cloud/requests/join_network_new_device.dart';
import 'package:magicshare_app/model/cloud/requests/send_link_notification_request.dart';
import 'package:magicshare_app/model/cloud/results/create_account_result.dart';
import 'package:magicshare_app/model/cloud/results/create_join_token_result.dart';
import 'package:magicshare_app/model/cloud/results/delete_account_result.dart';
import 'package:magicshare_app/model/cloud/results/health_result.dart';
import 'package:magicshare_app/model/cloud/results/join_network_result.dart';
import 'package:magicshare_app/model/cloud/results/poll_pending_wakes_result.dart';
import 'package:magicshare_app/model/cloud/results/preview_join_token_result.dart';
import 'package:magicshare_app/model/cloud/results/register_device_result.dart';
import 'package:magicshare_app/model/cloud/results/remove_device_result.dart';
import 'package:magicshare_app/model/cloud/results/send_link_notification_result.dart';
import 'package:magicshare_app/model/cloud/results/send_wake_result.dart';

/// Type for the underlying callable invocation. Allows the client to be
/// constructed with a fake invoker in tests, avoiding the need to mock the
/// non-mockable [FirebaseFunctions] / [HttpsCallable] hierarchy directly.
typedef HttpsCallableInvoker =
    Future<Object?> Function(
      String name,
      Object? data,
    );

/// Typed wrapper around every callable exported by firebase/functions/src.
/// All wrappers translate [FirebaseFunctionsException] to [CloudException]
/// so callers only need to handle one error type.
class CloudFunctionsClient {
  CloudFunctionsClient({HttpsCallableInvoker? invoker}) : _invoke = invoker ?? _defaultInvoker;

  final HttpsCallableInvoker _invoke;

  /// Default invoker — creates a region-pinned [FirebaseFunctions] instance
  /// per call. Cheap (the SDK caches under the hood) and keeps the region
  /// guarantee in one place.
  static Future<Object?> _defaultInvoker(String name, Object? data) async {
    try {
      final result = await FirebaseFunctions.instanceFor(region: cloudFunctionsRegion).httpsCallable(name).call<Object?>(data);
      return result.data;
    } on FirebaseFunctionsException catch (e) {
      throw CloudException.fromFirebase(e);
    }
  }

  Future<T> _call<T>(
    String name,
    Object? data,
    T Function(Object? raw) decode,
  ) async {
    try {
      final raw = await _invoke(name, data);
      return decode(raw);
    } on CloudException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      throw CloudException.fromFirebase(e);
    }
  }

  /// Diagnostic probe — no auth, returns service metadata.
  Future<HealthResult> health() {
    return _call('health', null, (raw) => HealthResult.fromJson(_asMap(raw)));
  }

  /// Idempotent: returns `created: false` if the account already exists.
  Future<CreateAccountResult> createAccount() {
    return _call(
      'createAccount',
      null,
      (raw) => CreateAccountResult.fromJson(_asMap(raw)),
    );
  }

  /// Cascades to all child devices in one transaction.
  Future<DeleteAccountResult> deleteAccount() {
    return _call(
      'deleteAccount',
      null,
      (raw) => DeleteAccountResult.fromJson(_asMap(raw)),
    );
  }

  Future<RegisterDeviceResult> registerDevice({
    required String deviceId,
    required String displayName,
    required CloudDeviceIcon icon,
    required CloudDevicePlatform platform,
    required String? fcmToken,
    required String? fingerprint,
  }) {
    return _call(
      'registerDevice',
      <String, dynamic>{
        'deviceId': deviceId,
        'displayName': displayName,
        'icon': icon.name,
        'platform': platform.name,
        'fcmToken': fcmToken,
        'fingerprint': fingerprint,
      },
      (raw) => RegisterDeviceResult.fromJson(_asMap(raw)),
    );
  }

  Future<void> renameDevice({
    required String deviceId,
    required String displayName,
  }) async {
    await _call(
      'renameDevice',
      <String, dynamic>{
        'deviceId': deviceId,
        'displayName': displayName,
      },
      _ignoreResponse,
    );
  }

  Future<void> setDeviceIcon({
    required String deviceId,
    required CloudDeviceIcon icon,
  }) async {
    await _call(
      'setDeviceIcon',
      <String, dynamic>{
        'deviceId': deviceId,
        'icon': icon.name,
      },
      _ignoreResponse,
    );
  }

  /// Cascades to delete the parent account when this was the last device.
  Future<RemoveDeviceResult> removeDevice({required String deviceId}) {
    return _call(
      'removeDevice',
      <String, dynamic>{'deviceId': deviceId},
      (raw) => RemoveDeviceResult.fromJson(_asMap(raw)),
    );
  }

  Future<CreateJoinTokenResult> createJoinToken({
    required String issuingDeviceId,
  }) {
    return _call(
      'createJoinToken',
      <String, dynamic>{'issuingDeviceId': issuingDeviceId},
      (raw) => CreateJoinTokenResult.fromJson(_asMap(raw)),
    );
  }

  /// Token-authorised: does not require the caller to be a member of the
  /// target account.
  Future<PreviewJoinTokenResult> previewJoinToken({
    required String tokenId,
  }) {
    return _call(
      'previewJoinToken',
      <String, dynamic>{'tokenId': tokenId},
      (raw) => PreviewJoinTokenResult.fromJson(_asMap(raw)),
    );
  }

  /// When the caller has no source account doc on this UID
  /// (welcome-card route — anon sign-in happened only to authenticate
  /// the call), pass [newDevice] so the backend can populate the
  /// fresh device doc under the target account. Existing-source-group
  /// callers omit it; the backend copies the source device's identity
  /// over and ignores [newDevice] if supplied.
  Future<JoinNetworkResult> joinNetwork({
    required String tokenId,
    required String deviceId,
    JoinNetworkNewDevice? newDevice,
  }) {
    return _call(
      'joinNetwork',
      <String, dynamic>{
        'tokenId': tokenId,
        'deviceId': deviceId,
        if (newDevice != null) 'newDevice': newDevice.toJson(),
      },
      (raw) => JoinNetworkResult.fromJson(_asMap(raw)),
    );
  }

  Future<SendWakeResult> sendWake({
    required String sourceDeviceId,
    required String targetDeviceId,
    required String payload,
  }) {
    return _call(
      'sendWake',
      <String, dynamic>{
        'sourceDeviceId': sourceDeviceId,
        'targetDeviceId': targetDeviceId,
        'payload': payload,
      },
      (raw) => SendWakeResult.fromJson(_asMap(raw)),
    );
  }

  /// Accepts either [PlaintextLinkNotificationRequest] or
  /// [EncryptedLinkNotificationRequest] — the discriminator is encoded as
  /// `mode: plaintext|encrypted` per the backend's
  /// `SendLinkNotificationInput`.
  Future<SendLinkNotificationResult> sendLinkNotification(
    SendLinkNotificationRequest request,
  ) {
    return _call(
      'sendLinkNotification',
      request.toJson(),
      (raw) => SendLinkNotificationResult.fromJson(_asMap(raw)),
    );
  }

  /// Linux polling fallback. Atomically removes the inbox items it returns,
  /// so the caller is responsible for handling them — re-polling will not
  /// re-deliver.
  Future<PollPendingWakesResult> pollPendingWakes({
    required String deviceId,
  }) {
    return _call(
      'pollPendingWakes',
      <String, dynamic>{'deviceId': deviceId},
      (raw) => PollPendingWakesResult.fromMap(_asMap(raw)),
    );
  }
}

Object? _ignoreResponse(Object? _) => null;

@visibleForTesting
Map<String, dynamic> debugAsMap(Object? raw) => _asMap(raw);

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map) {
    // The platform-channel bridge between Flutter and the native
    // Firebase Functions SDKs delivers nested maps as
    // `Map<Object?, Object?>` and nested lists with the same loose
    // typing. dart_mappable's class decoders insist on
    // `Map<String, dynamic>` at every level, so we deep-cast here
    // once and let downstream decoders work with the strict shape.
    return _deepCastMap(raw);
  }
  throw CloudException(
    code: CloudErrorCode.unknown,
    message: 'Expected callable to return a map but got ${raw.runtimeType}',
  );
}

Map<String, dynamic> _deepCastMap(Map<Object?, Object?> raw) {
  final out = <String, dynamic>{};
  raw.forEach((key, value) {
    if (key is! String) {
      throw CloudException(
        code: CloudErrorCode.unknown,
        message: 'Non-string map key in callable response: ${key.runtimeType}',
      );
    }
    out[key] = _deepCastValue(value);
  });
  return out;
}

Object? _deepCastValue(Object? value) {
  if (value is Map<Object?, Object?>) return _deepCastMap(value);
  if (value is List) {
    return value.map(_deepCastValue).toList();
  }
  return value;
}
