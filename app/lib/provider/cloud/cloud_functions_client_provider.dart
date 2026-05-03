import 'package:magicshare_app/cloud/cloud_functions_client.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Stateless DI holder for the [CloudFunctionsClient]. Override in
/// tests with a client backed by a fake [HttpsCallableInvoker].
final cloudFunctionsClientProvider = Provider<CloudFunctionsClient>((ref) {
  return CloudFunctionsClient();
});
