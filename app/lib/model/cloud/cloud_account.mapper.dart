// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'cloud_account.dart';

class CloudAccountMapper extends ClassMapperBase<CloudAccount> {
  CloudAccountMapper._();

  static CloudAccountMapper? _instance;
  static CloudAccountMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CloudAccountMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'CloudAccount';

  static String _$accountId(CloudAccount v) => v.accountId;
  static const Field<CloudAccount, String> _f$accountId = Field(
    'accountId',
    _$accountId,
  );
  static int _$createdAtMs(CloudAccount v) => v.createdAtMs;
  static const Field<CloudAccount, int> _f$createdAtMs = Field(
    'createdAtMs',
    _$createdAtMs,
  );
  static int _$lastActiveAtMs(CloudAccount v) => v.lastActiveAtMs;
  static const Field<CloudAccount, int> _f$lastActiveAtMs = Field(
    'lastActiveAtMs',
    _$lastActiveAtMs,
  );
  static int _$deviceCount(CloudAccount v) => v.deviceCount;
  static const Field<CloudAccount, int> _f$deviceCount = Field(
    'deviceCount',
    _$deviceCount,
  );

  @override
  final MappableFields<CloudAccount> fields = const {
    #accountId: _f$accountId,
    #createdAtMs: _f$createdAtMs,
    #lastActiveAtMs: _f$lastActiveAtMs,
    #deviceCount: _f$deviceCount,
  };

  static CloudAccount _instantiate(DecodingData data) {
    return CloudAccount(
      accountId: data.dec(_f$accountId),
      createdAtMs: data.dec(_f$createdAtMs),
      lastActiveAtMs: data.dec(_f$lastActiveAtMs),
      deviceCount: data.dec(_f$deviceCount),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static CloudAccount fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CloudAccount>(map);
  }

  static CloudAccount deserialize(String json) {
    return ensureInitialized().decodeJson<CloudAccount>(json);
  }
}

mixin CloudAccountMappable {
  String serialize() {
    return CloudAccountMapper.ensureInitialized().encodeJson<CloudAccount>(
      this as CloudAccount,
    );
  }

  Map<String, dynamic> toJson() {
    return CloudAccountMapper.ensureInitialized().encodeMap<CloudAccount>(
      this as CloudAccount,
    );
  }

  CloudAccountCopyWith<CloudAccount, CloudAccount, CloudAccount> get copyWith =>
      _CloudAccountCopyWithImpl<CloudAccount, CloudAccount>(
        this as CloudAccount,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return CloudAccountMapper.ensureInitialized().stringifyValue(
      this as CloudAccount,
    );
  }

  @override
  bool operator ==(Object other) {
    return CloudAccountMapper.ensureInitialized().equalsValue(
      this as CloudAccount,
      other,
    );
  }

  @override
  int get hashCode {
    return CloudAccountMapper.ensureInitialized().hashValue(
      this as CloudAccount,
    );
  }
}

extension CloudAccountValueCopy<$R, $Out>
    on ObjectCopyWith<$R, CloudAccount, $Out> {
  CloudAccountCopyWith<$R, CloudAccount, $Out> get $asCloudAccount =>
      $base.as((v, t, t2) => _CloudAccountCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class CloudAccountCopyWith<$R, $In extends CloudAccount, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? accountId,
    int? createdAtMs,
    int? lastActiveAtMs,
    int? deviceCount,
  });
  CloudAccountCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _CloudAccountCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CloudAccount, $Out>
    implements CloudAccountCopyWith<$R, CloudAccount, $Out> {
  _CloudAccountCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CloudAccount> $mapper =
      CloudAccountMapper.ensureInitialized();
  @override
  $R call({
    String? accountId,
    int? createdAtMs,
    int? lastActiveAtMs,
    int? deviceCount,
  }) => $apply(
    FieldCopyWithData({
      if (accountId != null) #accountId: accountId,
      if (createdAtMs != null) #createdAtMs: createdAtMs,
      if (lastActiveAtMs != null) #lastActiveAtMs: lastActiveAtMs,
      if (deviceCount != null) #deviceCount: deviceCount,
    }),
  );
  @override
  CloudAccount $make(CopyWithData data) => CloudAccount(
    accountId: data.get(#accountId, or: $value.accountId),
    createdAtMs: data.get(#createdAtMs, or: $value.createdAtMs),
    lastActiveAtMs: data.get(#lastActiveAtMs, or: $value.lastActiveAtMs),
    deviceCount: data.get(#deviceCount, or: $value.deviceCount),
  );

  @override
  CloudAccountCopyWith<$R2, CloudAccount, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _CloudAccountCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

