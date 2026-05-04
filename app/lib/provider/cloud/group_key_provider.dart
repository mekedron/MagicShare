import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:magicshare_app/cloud/crypto/group_key_codec.dart';
import 'package:magicshare_app/provider/cloud/secure_storage_provider.dart';
import 'package:magicshare_app/provider/persistence_provider.dart';
import 'package:magicshare_app/util/native/secure_storage_service.dart';
import 'package:refena_flutter/refena_flutter.dart';

final _logger = Logger('CloudGroupKey');

/// Discriminated state for the group key lifecycle.
sealed class GroupKeyState {
  const GroupKeyState();
}

/// Initial read in flight — emitted while `init()` is loading the
/// persisted key.
class GroupKeyLoading extends GroupKeyState {
  const GroupKeyLoading();
}

/// No key on this device. Either the user has not yet bootstrapped a fresh
/// account, or the key was wiped via `clear()`.
class GroupKeyMissing extends GroupKeyState {
  const GroupKeyMissing();
}

class GroupKeyReady extends GroupKeyState {
  const GroupKeyReady(this.key);
  final Uint8List key;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GroupKeyReady && other.key.length == key.length && _constantTimeEqual(key, other.key);

  @override
  int get hashCode => Object.hashAll(key);
}

class GroupKeyFailed extends GroupKeyState {
  const GroupKeyFailed({required this.message, required this.error});
  final String message;
  final Object error;
}

/// Owns the device-group AES-GCM key.
///
/// - On first launch the key is absent; the bootstrap service calls
///   [ensureForNewAccount] when `createAccount` returns `created: true` (or
///   in the crash-recovery branch when no peers exist and the slot is
///   empty), which generates and persists a fresh 32-byte key.
/// - Pairing (Epic 11) installs a key received over LAN via [replace].
/// - Deleting the device group calls [clear] which wipes both the group
///   key (secure storage) and the per-device id (SharedPreferences via
///   [clearDeviceId]) so the next bootstrap registers afresh.
class GroupKeyService extends Notifier<GroupKeyState> {
  GroupKeyService({
    required SecureStorageService storage,
    required Future<void> Function() clearDeviceId,
    Uint8List Function()? keyGenerator,
  }) : _storage = storage,
       _clearDeviceId = clearDeviceId,
       _generateKey = keyGenerator ?? generateGroupKey;

  final SecureStorageService _storage;
  final Future<void> Function() _clearDeviceId;
  final Uint8List Function() _generateKey;
  bool _started = false;

  @override
  GroupKeyState init() {
    if (!_started) {
      _started = true;
      unawaited(_loadFromStorage());
    }
    return const GroupKeyLoading();
  }

  Future<void> _loadFromStorage() async {
    try {
      final stored = await _storage.read(cloudGroupKeyKey);
      if (stored == null || stored.isEmpty) {
        state = const GroupKeyMissing();
        return;
      }
      state = GroupKeyReady(_decodeKey(stored));
    } catch (e, st) {
      _logger.warning('Reading group key from secure storage failed', e, st);
      state = GroupKeyFailed(message: 'Reading stored key failed: $e', error: e);
    }
  }

  /// Generates and persists a fresh key. Idempotent: if a key is already
  /// loaded, returns it without rotating — preventing accidental key
  /// rotation that would orphan existing peer devices.
  Future<Uint8List> ensureForNewAccount() async {
    final current = state;
    if (current is GroupKeyReady) return current.key;
    final key = _generateKey();
    await _storage.write(cloudGroupKeyKey, _encodeKey(key));
    state = GroupKeyReady(key);
    return key;
  }

  /// Installs an externally-supplied key (received over LAN during pairing,
  /// Epic 11). Replaces any existing key.
  Future<void> replace(Uint8List key) async {
    if (key.length != groupKeyLengthBytes) {
      throw ArgumentError(
        'Group key must be $groupKeyLengthBytes bytes; got ${key.length}',
      );
    }
    await _storage.write(cloudGroupKeyKey, _encodeKey(key));
    state = GroupKeyReady(key);
  }

  /// Wipes the group key AND the device id (so a destroy-then-bootstrap
  /// cycle registers a fresh device row instead of resurrecting the old
  /// id under the new account).
  Future<void> clear() async {
    await _storage.delete(cloudGroupKeyKey);
    await _clearDeviceId();
    state = const GroupKeyMissing();
  }
}

String _encodeKey(Uint8List key) => base64Encode(key);

Uint8List _decodeKey(String stored) {
  final bytes = Uint8List.fromList(base64Decode(stored));
  if (bytes.length != groupKeyLengthBytes) {
    throw StateError(
      'Stored group key has wrong length: ${bytes.length} bytes',
    );
  }
  return bytes;
}

bool _constantTimeEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

final groupKeyProvider = NotifierProvider<GroupKeyService, GroupKeyState>((ref) {
  final persistence = ref.read(persistenceProvider);
  return GroupKeyService(
    storage: ref.read(secureStorageProvider),
    clearDeviceId: persistence.clearCloudDeviceId,
  );
});
