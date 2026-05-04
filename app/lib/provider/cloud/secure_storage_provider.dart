import 'package:magicshare_app/util/native/secure_storage_service.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Stateless DI: cloud notifiers `ref.read(secureStorageProvider)` instead of
/// instantiating the service directly, so tests can override with a fake.
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});
