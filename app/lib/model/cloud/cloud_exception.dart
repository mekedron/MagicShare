import 'package:cloud_functions/cloud_functions.dart';

/// Typed counterpart to the `HttpsError` codes thrown by every Cloud
/// Function in firebase/functions/src/. Lists exactly the codes the backend
/// actually surfaces today — `unknown` covers anything else.
enum CloudErrorCode {
  /// Caller isn't signed in (auth.ts:14).
  unauthenticated,

  /// Schema validation failed (validation.ts:32, 126).
  invalidArgument,

  /// Account, device, or token not found (devices.ts:205,
  /// account-access.ts:39, pairing.ts:174,263).
  notFound,

  /// Business-logic precondition failed: account missing on registerDevice,
  /// token consumed/expired, self-join attempt, etc.
  failedPrecondition,

  /// Soft rate-limit exceeded (devices.ts:107 for presence;
  /// rate-limit.ts for sendWake / sendLinkNotification).
  resourceExhausted,

  /// Anything the backend hasn't categorised — network errors, server
  /// crashes, future codes added without a matching enum value.
  unknown,
}

/// Maps the Firebase code string surfaced by [FirebaseFunctionsException]
/// to a [CloudErrorCode]. Unknown / future codes return [CloudErrorCode.unknown].
CloudErrorCode cloudErrorCodeFromFirebase(String code) {
  switch (code) {
    case 'unauthenticated':
      return CloudErrorCode.unauthenticated;
    case 'invalid-argument':
      return CloudErrorCode.invalidArgument;
    case 'not-found':
      return CloudErrorCode.notFound;
    case 'failed-precondition':
      return CloudErrorCode.failedPrecondition;
    case 'resource-exhausted':
      return CloudErrorCode.resourceExhausted;
    default:
      return CloudErrorCode.unknown;
  }
}

/// Single typed exception thrown by every wrapper in `CloudFunctionsClient`.
/// Callers `switch` on [code] to react; [message] preserves the server-side
/// human-readable detail; [details] carries the raw `details` map when the
/// backend attaches one.
class CloudException implements Exception {
  final CloudErrorCode code;
  final String message;
  final Object? details;

  const CloudException({
    required this.code,
    required this.message,
    this.details,
  });

  /// Convenience constructor for the common case of catching a
  /// [FirebaseFunctionsException] and re-throwing as a typed cloud error.
  factory CloudException.fromFirebase(FirebaseFunctionsException error) {
    return CloudException(
      code: cloudErrorCodeFromFirebase(error.code),
      message: error.message ?? error.code,
      details: error.details,
    );
  }

  @override
  String toString() => 'CloudException(${code.name}): $message';
}
