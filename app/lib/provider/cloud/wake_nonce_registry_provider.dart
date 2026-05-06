import 'package:magicshare_app/cloud/wake/wake_nonce_registry.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Single shared [WakeNonceRegistry] for the main isolate. Every code
/// path that needs to register a nonce (foreground FCM listener,
/// drain-from-persistence pump on app resume) and every path that
/// consumes one (the receive controller's auto-accept hook) reads it
/// through this provider.
final wakeNonceRegistryProvider = Provider<WakeNonceRegistry>((ref) {
  return WakeNonceRegistry();
});
