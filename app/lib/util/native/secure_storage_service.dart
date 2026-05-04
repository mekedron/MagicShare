import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Storage key for the locally-generated, stable device id used in the cloud
/// `accounts/{uid}/devices/{deviceId}` path. Generated on first launch and
/// persisted across reinstalls / app data clears (subject to the OS
/// keystore's own retention semantics).
const String cloudDeviceIdKey = 'cloud.device_id';

/// Storage key for the 32-byte symmetric group key used to encrypt wake and
/// link payloads exchanged via FCM. The key never leaves the device through
/// the cloud — it is generated locally on account creation and propagated
/// to peers only over the LAN-side pairing handshake (Epic 11).
const String cloudGroupKeyKey = 'cloud.group_key';

/// Note on the spec line about "the account ID is stored locally in secure
/// storage" (cloud-sync-spec.md §5.3): the account ID is the Firebase
/// Auth UID, which `FirebaseAuth.instance` already persists in the platform
/// keystore. We do not duplicate it here.
class SecureStorageGateway {
  SecureStorageGateway({
    required this.read,
    required this.write,
    required this.delete,
  });

  final Future<String?> Function(String key) read;
  final Future<void> Function(String key, String value) write;
  final Future<void> Function(String key) delete;

  factory SecureStorageGateway.live() {
    const storage = FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    return SecureStorageGateway(
      read: (key) => storage.read(key: key),
      write: (key, value) => storage.write(key: key, value: value),
      delete: (key) => storage.delete(key: key),
    );
  }
}

/// Thin wrapper exposing only the operations the cloud layer needs.
/// All consumers go through this surface so tests can override the gateway.
class SecureStorageService {
  SecureStorageService({SecureStorageGateway? gateway}) : _gateway = gateway ?? SecureStorageGateway.live();

  final SecureStorageGateway _gateway;

  Future<String?> read(String key) => _gateway.read(key);
  Future<void> write(String key, String value) => _gateway.write(key, value);
  Future<void> delete(String key) => _gateway.delete(key);
}
