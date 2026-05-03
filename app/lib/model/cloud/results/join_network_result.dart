import 'package:dart_mappable/dart_mappable.dart';
import 'package:magicshare_app/model/cloud/join_token_preview.dart';

part 'join_network_result.mapper.dart';

/// Mirrors `JoinNetworkResult` in firebase/functions/src/pairing.ts.
@MappableClass()
class JoinNetworkResult with JoinNetworkResultMappable {
  /// The new account this device now belongs to (the issuing device's
  /// account).
  final String accountId;

  /// True when the joining device was the last member of its previous
  /// account and the backend deleted that account in the same transaction.
  final bool oldAccountDeleted;

  /// Devices that now share the new account, including the freshly
  /// joined device.
  final List<JoinTokenPreviewDevice> devices;

  const JoinNetworkResult({
    required this.accountId,
    required this.oldAccountDeleted,
    required this.devices,
  });

  static const fromJson = JoinNetworkResultMapper.fromJson;
}
