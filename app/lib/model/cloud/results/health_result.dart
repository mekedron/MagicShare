import 'package:dart_mappable/dart_mappable.dart';

part 'health_result.mapper.dart';

/// Mirrors the inline shape returned by the `health` callable in
/// firebase/functions/src/index.ts.
@MappableClass()
class HealthResult with HealthResultMappable {
  final bool ok;
  final String service;
  final String version;

  const HealthResult({
    required this.ok,
    required this.service,
    required this.version,
  });

  static const fromJson = HealthResultMapper.fromJson;
}
