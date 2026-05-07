// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'device.dart';

class DeviceTypeMapper extends EnumMapper<DeviceType> {
  DeviceTypeMapper._();

  static DeviceTypeMapper? _instance;
  static DeviceTypeMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DeviceTypeMapper._());
    }
    return _instance!;
  }

  static DeviceType fromValue(dynamic value) {
    ensureInitialized();
    return MapperContainer.globals.fromValue(value);
  }

  @override
  DeviceType decode(dynamic value) {
    switch (value) {
      case r'mobile':
        return DeviceType.mobile;
      case r'desktop':
        return DeviceType.desktop;
      case r'web':
        return DeviceType.web;
      case r'headless':
        return DeviceType.headless;
      case r'server':
        return DeviceType.server;
      default:
        return DeviceType.values[1];
    }
  }

  @override
  dynamic encode(DeviceType self) {
    switch (self) {
      case DeviceType.mobile:
        return r'mobile';
      case DeviceType.desktop:
        return r'desktop';
      case DeviceType.web:
        return r'web';
      case DeviceType.headless:
        return r'headless';
      case DeviceType.server:
        return r'server';
    }
  }
}

extension DeviceTypeMapperExtension on DeviceType {
  String toValue() {
    DeviceTypeMapper.ensureInitialized();
    return MapperContainer.globals.toValue<DeviceType>(this) as String;
  }
}

class DiscoveryMethodMapper extends ClassMapperBase<DiscoveryMethod> {
  DiscoveryMethodMapper._();

  static DiscoveryMethodMapper? _instance;
  static DiscoveryMethodMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DiscoveryMethodMapper._());
      MulticastDiscoveryMapper.ensureInitialized();
      HttpDiscoveryMapper.ensureInitialized();
      SignalingDiscoveryMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'DiscoveryMethod';

  @override
  final MappableFields<DiscoveryMethod> fields = const {};

  static DiscoveryMethod _instantiate(DecodingData data) {
    throw MapperException.missingConstructor('DiscoveryMethod');
  }

  @override
  final Function instantiate = _instantiate;

  static DiscoveryMethod fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<DiscoveryMethod>(map);
  }

  static DiscoveryMethod deserialize(String json) {
    return ensureInitialized().decodeJson<DiscoveryMethod>(json);
  }
}

mixin DiscoveryMethodMappable {
  String serialize();
  Map<String, dynamic> toJson();
  DiscoveryMethodCopyWith<DiscoveryMethod, DiscoveryMethod, DiscoveryMethod> get copyWith;
}

abstract class DiscoveryMethodCopyWith<$R, $In extends DiscoveryMethod, $Out> implements ClassCopyWith<$R, $In, $Out> {
  $R call();
  DiscoveryMethodCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class MulticastDiscoveryMapper extends ClassMapperBase<MulticastDiscovery> {
  MulticastDiscoveryMapper._();

  static MulticastDiscoveryMapper? _instance;
  static MulticastDiscoveryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = MulticastDiscoveryMapper._());
      DiscoveryMethodMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'MulticastDiscovery';

  @override
  final MappableFields<MulticastDiscovery> fields = const {};

  static MulticastDiscovery _instantiate(DecodingData data) {
    return MulticastDiscovery();
  }

  @override
  final Function instantiate = _instantiate;

  static MulticastDiscovery fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<MulticastDiscovery>(map);
  }

  static MulticastDiscovery deserialize(String json) {
    return ensureInitialized().decodeJson<MulticastDiscovery>(json);
  }
}

mixin MulticastDiscoveryMappable {
  String serialize() {
    return MulticastDiscoveryMapper.ensureInitialized().encodeJson<MulticastDiscovery>(this as MulticastDiscovery);
  }

  Map<String, dynamic> toJson() {
    return MulticastDiscoveryMapper.ensureInitialized().encodeMap<MulticastDiscovery>(this as MulticastDiscovery);
  }

  MulticastDiscoveryCopyWith<MulticastDiscovery, MulticastDiscovery, MulticastDiscovery> get copyWith =>
      _MulticastDiscoveryCopyWithImpl<MulticastDiscovery, MulticastDiscovery>(
        this as MulticastDiscovery,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return MulticastDiscoveryMapper.ensureInitialized().stringifyValue(
      this as MulticastDiscovery,
    );
  }

  @override
  bool operator ==(Object other) {
    return MulticastDiscoveryMapper.ensureInitialized().equalsValue(
      this as MulticastDiscovery,
      other,
    );
  }

  @override
  int get hashCode {
    return MulticastDiscoveryMapper.ensureInitialized().hashValue(
      this as MulticastDiscovery,
    );
  }
}

extension MulticastDiscoveryValueCopy<$R, $Out> on ObjectCopyWith<$R, MulticastDiscovery, $Out> {
  MulticastDiscoveryCopyWith<$R, MulticastDiscovery, $Out> get $asMulticastDiscovery => $base.as(
        (v, t, t2) => _MulticastDiscoveryCopyWithImpl<$R, $Out>(v, t, t2),
      );
}

abstract class MulticastDiscoveryCopyWith<$R, $In extends MulticastDiscovery, $Out> implements DiscoveryMethodCopyWith<$R, $In, $Out> {
  @override
  $R call();
  MulticastDiscoveryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _MulticastDiscoveryCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, MulticastDiscovery, $Out>
    implements MulticastDiscoveryCopyWith<$R, MulticastDiscovery, $Out> {
  _MulticastDiscoveryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<MulticastDiscovery> $mapper = MulticastDiscoveryMapper.ensureInitialized();
  @override
  $R call() => $apply(FieldCopyWithData({}));
  @override
  MulticastDiscovery $make(CopyWithData data) => MulticastDiscovery();

  @override
  MulticastDiscoveryCopyWith<$R2, MulticastDiscovery, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) =>
      _MulticastDiscoveryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class HttpDiscoveryMapper extends ClassMapperBase<HttpDiscovery> {
  HttpDiscoveryMapper._();

  static HttpDiscoveryMapper? _instance;
  static HttpDiscoveryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = HttpDiscoveryMapper._());
      DiscoveryMethodMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'HttpDiscovery';

  static String _$ip(HttpDiscovery v) => v.ip;
  static const Field<HttpDiscovery, String> _f$ip = Field('ip', _$ip);

  @override
  final MappableFields<HttpDiscovery> fields = const {#ip: _f$ip};

  static HttpDiscovery _instantiate(DecodingData data) {
    return HttpDiscovery(ip: data.dec(_f$ip));
  }

  @override
  final Function instantiate = _instantiate;

  static HttpDiscovery fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<HttpDiscovery>(map);
  }

  static HttpDiscovery deserialize(String json) {
    return ensureInitialized().decodeJson<HttpDiscovery>(json);
  }
}

mixin HttpDiscoveryMappable {
  String serialize() {
    return HttpDiscoveryMapper.ensureInitialized().encodeJson<HttpDiscovery>(
      this as HttpDiscovery,
    );
  }

  Map<String, dynamic> toJson() {
    return HttpDiscoveryMapper.ensureInitialized().encodeMap<HttpDiscovery>(
      this as HttpDiscovery,
    );
  }

  HttpDiscoveryCopyWith<HttpDiscovery, HttpDiscovery, HttpDiscovery> get copyWith => _HttpDiscoveryCopyWithImpl<HttpDiscovery, HttpDiscovery>(
        this as HttpDiscovery,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return HttpDiscoveryMapper.ensureInitialized().stringifyValue(
      this as HttpDiscovery,
    );
  }

  @override
  bool operator ==(Object other) {
    return HttpDiscoveryMapper.ensureInitialized().equalsValue(
      this as HttpDiscovery,
      other,
    );
  }

  @override
  int get hashCode {
    return HttpDiscoveryMapper.ensureInitialized().hashValue(
      this as HttpDiscovery,
    );
  }
}

extension HttpDiscoveryValueCopy<$R, $Out> on ObjectCopyWith<$R, HttpDiscovery, $Out> {
  HttpDiscoveryCopyWith<$R, HttpDiscovery, $Out> get $asHttpDiscovery => $base.as((v, t, t2) => _HttpDiscoveryCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class HttpDiscoveryCopyWith<$R, $In extends HttpDiscovery, $Out> implements DiscoveryMethodCopyWith<$R, $In, $Out> {
  @override
  $R call({String? ip});
  HttpDiscoveryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _HttpDiscoveryCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, HttpDiscovery, $Out>
    implements HttpDiscoveryCopyWith<$R, HttpDiscovery, $Out> {
  _HttpDiscoveryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<HttpDiscovery> $mapper = HttpDiscoveryMapper.ensureInitialized();
  @override
  $R call({String? ip}) => $apply(FieldCopyWithData({if (ip != null) #ip: ip}));
  @override
  HttpDiscovery $make(CopyWithData data) => HttpDiscovery(ip: data.get(#ip, or: $value.ip));

  @override
  HttpDiscoveryCopyWith<$R2, HttpDiscovery, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) =>
      _HttpDiscoveryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class SignalingDiscoveryMapper extends ClassMapperBase<SignalingDiscovery> {
  SignalingDiscoveryMapper._();

  static SignalingDiscoveryMapper? _instance;
  static SignalingDiscoveryMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SignalingDiscoveryMapper._());
      DiscoveryMethodMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'SignalingDiscovery';

  static String _$signalingServer(SignalingDiscovery v) => v.signalingServer;
  static const Field<SignalingDiscovery, String> _f$signalingServer = Field(
    'signalingServer',
    _$signalingServer,
  );

  @override
  final MappableFields<SignalingDiscovery> fields = const {
    #signalingServer: _f$signalingServer,
  };

  static SignalingDiscovery _instantiate(DecodingData data) {
    return SignalingDiscovery(signalingServer: data.dec(_f$signalingServer));
  }

  @override
  final Function instantiate = _instantiate;

  static SignalingDiscovery fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SignalingDiscovery>(map);
  }

  static SignalingDiscovery deserialize(String json) {
    return ensureInitialized().decodeJson<SignalingDiscovery>(json);
  }
}

mixin SignalingDiscoveryMappable {
  String serialize() {
    return SignalingDiscoveryMapper.ensureInitialized().encodeJson<SignalingDiscovery>(this as SignalingDiscovery);
  }

  Map<String, dynamic> toJson() {
    return SignalingDiscoveryMapper.ensureInitialized().encodeMap<SignalingDiscovery>(this as SignalingDiscovery);
  }

  SignalingDiscoveryCopyWith<SignalingDiscovery, SignalingDiscovery, SignalingDiscovery> get copyWith =>
      _SignalingDiscoveryCopyWithImpl<SignalingDiscovery, SignalingDiscovery>(
        this as SignalingDiscovery,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return SignalingDiscoveryMapper.ensureInitialized().stringifyValue(
      this as SignalingDiscovery,
    );
  }

  @override
  bool operator ==(Object other) {
    return SignalingDiscoveryMapper.ensureInitialized().equalsValue(
      this as SignalingDiscovery,
      other,
    );
  }

  @override
  int get hashCode {
    return SignalingDiscoveryMapper.ensureInitialized().hashValue(
      this as SignalingDiscovery,
    );
  }
}

extension SignalingDiscoveryValueCopy<$R, $Out> on ObjectCopyWith<$R, SignalingDiscovery, $Out> {
  SignalingDiscoveryCopyWith<$R, SignalingDiscovery, $Out> get $asSignalingDiscovery => $base.as(
        (v, t, t2) => _SignalingDiscoveryCopyWithImpl<$R, $Out>(v, t, t2),
      );
}

abstract class SignalingDiscoveryCopyWith<$R, $In extends SignalingDiscovery, $Out> implements DiscoveryMethodCopyWith<$R, $In, $Out> {
  @override
  $R call({String? signalingServer});
  SignalingDiscoveryCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _SignalingDiscoveryCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, SignalingDiscovery, $Out>
    implements SignalingDiscoveryCopyWith<$R, SignalingDiscovery, $Out> {
  _SignalingDiscoveryCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SignalingDiscovery> $mapper = SignalingDiscoveryMapper.ensureInitialized();
  @override
  $R call({String? signalingServer}) => $apply(
        FieldCopyWithData({
          if (signalingServer != null) #signalingServer: signalingServer,
        }),
      );
  @override
  SignalingDiscovery $make(CopyWithData data) => SignalingDiscovery(
        signalingServer: data.get(#signalingServer, or: $value.signalingServer),
      );

  @override
  SignalingDiscoveryCopyWith<$R2, SignalingDiscovery, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) =>
      _SignalingDiscoveryCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class DeviceEndpointMapper extends ClassMapperBase<DeviceEndpoint> {
  DeviceEndpointMapper._();

  static DeviceEndpointMapper? _instance;
  static DeviceEndpointMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DeviceEndpointMapper._());
      HttpEndpointMapper.ensureInitialized();
      SignalingEndpointMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'DeviceEndpoint';

  @override
  final MappableFields<DeviceEndpoint> fields = const {};

  static DeviceEndpoint _instantiate(DecodingData data) {
    throw MapperException.missingConstructor('DeviceEndpoint');
  }

  @override
  final Function instantiate = _instantiate;

  static DeviceEndpoint fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<DeviceEndpoint>(map);
  }

  static DeviceEndpoint deserialize(String json) {
    return ensureInitialized().decodeJson<DeviceEndpoint>(json);
  }
}

mixin DeviceEndpointMappable {
  String serialize();
  Map<String, dynamic> toJson();
  DeviceEndpointCopyWith<DeviceEndpoint, DeviceEndpoint, DeviceEndpoint> get copyWith;
}

abstract class DeviceEndpointCopyWith<$R, $In extends DeviceEndpoint, $Out> implements ClassCopyWith<$R, $In, $Out> {
  $R call();
  DeviceEndpointCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class HttpEndpointMapper extends ClassMapperBase<HttpEndpoint> {
  HttpEndpointMapper._();

  static HttpEndpointMapper? _instance;
  static HttpEndpointMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = HttpEndpointMapper._());
      DeviceEndpointMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'HttpEndpoint';

  static String _$ip(HttpEndpoint v) => v.ip;
  static const Field<HttpEndpoint, String> _f$ip = Field('ip', _$ip);
  static int _$port(HttpEndpoint v) => v.port;
  static const Field<HttpEndpoint, int> _f$port = Field('port', _$port);
  static bool _$https(HttpEndpoint v) => v.https;
  static const Field<HttpEndpoint, bool> _f$https = Field('https', _$https);
  static String _$certHash(HttpEndpoint v) => v.certHash;
  static const Field<HttpEndpoint, String> _f$certHash = Field(
    'certHash',
    _$certHash,
  );

  @override
  final MappableFields<HttpEndpoint> fields = const {
    #ip: _f$ip,
    #port: _f$port,
    #https: _f$https,
    #certHash: _f$certHash,
  };

  static HttpEndpoint _instantiate(DecodingData data) {
    return HttpEndpoint(
      ip: data.dec(_f$ip),
      port: data.dec(_f$port),
      https: data.dec(_f$https),
      certHash: data.dec(_f$certHash),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static HttpEndpoint fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<HttpEndpoint>(map);
  }

  static HttpEndpoint deserialize(String json) {
    return ensureInitialized().decodeJson<HttpEndpoint>(json);
  }
}

mixin HttpEndpointMappable {
  String serialize() {
    return HttpEndpointMapper.ensureInitialized().encodeJson<HttpEndpoint>(
      this as HttpEndpoint,
    );
  }

  Map<String, dynamic> toJson() {
    return HttpEndpointMapper.ensureInitialized().encodeMap<HttpEndpoint>(
      this as HttpEndpoint,
    );
  }

  HttpEndpointCopyWith<HttpEndpoint, HttpEndpoint, HttpEndpoint> get copyWith => _HttpEndpointCopyWithImpl<HttpEndpoint, HttpEndpoint>(
        this as HttpEndpoint,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return HttpEndpointMapper.ensureInitialized().stringifyValue(
      this as HttpEndpoint,
    );
  }

  @override
  bool operator ==(Object other) {
    return HttpEndpointMapper.ensureInitialized().equalsValue(
      this as HttpEndpoint,
      other,
    );
  }

  @override
  int get hashCode {
    return HttpEndpointMapper.ensureInitialized().hashValue(
      this as HttpEndpoint,
    );
  }
}

extension HttpEndpointValueCopy<$R, $Out> on ObjectCopyWith<$R, HttpEndpoint, $Out> {
  HttpEndpointCopyWith<$R, HttpEndpoint, $Out> get $asHttpEndpoint => $base.as((v, t, t2) => _HttpEndpointCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class HttpEndpointCopyWith<$R, $In extends HttpEndpoint, $Out> implements DeviceEndpointCopyWith<$R, $In, $Out> {
  @override
  $R call({String? ip, int? port, bool? https, String? certHash});
  HttpEndpointCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _HttpEndpointCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, HttpEndpoint, $Out> implements HttpEndpointCopyWith<$R, HttpEndpoint, $Out> {
  _HttpEndpointCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<HttpEndpoint> $mapper = HttpEndpointMapper.ensureInitialized();
  @override
  $R call({String? ip, int? port, bool? https, String? certHash}) => $apply(
        FieldCopyWithData({
          if (ip != null) #ip: ip,
          if (port != null) #port: port,
          if (https != null) #https: https,
          if (certHash != null) #certHash: certHash,
        }),
      );
  @override
  HttpEndpoint $make(CopyWithData data) => HttpEndpoint(
        ip: data.get(#ip, or: $value.ip),
        port: data.get(#port, or: $value.port),
        https: data.get(#https, or: $value.https),
        certHash: data.get(#certHash, or: $value.certHash),
      );

  @override
  HttpEndpointCopyWith<$R2, HttpEndpoint, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) =>
      _HttpEndpointCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class SignalingEndpointMapper extends ClassMapperBase<SignalingEndpoint> {
  SignalingEndpointMapper._();

  static SignalingEndpointMapper? _instance;
  static SignalingEndpointMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SignalingEndpointMapper._());
      DeviceEndpointMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'SignalingEndpoint';

  static String _$signalingId(SignalingEndpoint v) => v.signalingId;
  static const Field<SignalingEndpoint, String> _f$signalingId = Field(
    'signalingId',
    _$signalingId,
  );
  static String _$signalingServer(SignalingEndpoint v) => v.signalingServer;
  static const Field<SignalingEndpoint, String> _f$signalingServer = Field(
    'signalingServer',
    _$signalingServer,
  );
  static String _$serverToken(SignalingEndpoint v) => v.serverToken;
  static const Field<SignalingEndpoint, String> _f$serverToken = Field(
    'serverToken',
    _$serverToken,
  );

  @override
  final MappableFields<SignalingEndpoint> fields = const {
    #signalingId: _f$signalingId,
    #signalingServer: _f$signalingServer,
    #serverToken: _f$serverToken,
  };

  static SignalingEndpoint _instantiate(DecodingData data) {
    return SignalingEndpoint(
      signalingId: data.dec(_f$signalingId),
      signalingServer: data.dec(_f$signalingServer),
      serverToken: data.dec(_f$serverToken),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static SignalingEndpoint fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SignalingEndpoint>(map);
  }

  static SignalingEndpoint deserialize(String json) {
    return ensureInitialized().decodeJson<SignalingEndpoint>(json);
  }
}

mixin SignalingEndpointMappable {
  String serialize() {
    return SignalingEndpointMapper.ensureInitialized().encodeJson<SignalingEndpoint>(this as SignalingEndpoint);
  }

  Map<String, dynamic> toJson() {
    return SignalingEndpointMapper.ensureInitialized().encodeMap<SignalingEndpoint>(this as SignalingEndpoint);
  }

  SignalingEndpointCopyWith<SignalingEndpoint, SignalingEndpoint, SignalingEndpoint> get copyWith =>
      _SignalingEndpointCopyWithImpl<SignalingEndpoint, SignalingEndpoint>(
        this as SignalingEndpoint,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return SignalingEndpointMapper.ensureInitialized().stringifyValue(
      this as SignalingEndpoint,
    );
  }

  @override
  bool operator ==(Object other) {
    return SignalingEndpointMapper.ensureInitialized().equalsValue(
      this as SignalingEndpoint,
      other,
    );
  }

  @override
  int get hashCode {
    return SignalingEndpointMapper.ensureInitialized().hashValue(
      this as SignalingEndpoint,
    );
  }
}

extension SignalingEndpointValueCopy<$R, $Out> on ObjectCopyWith<$R, SignalingEndpoint, $Out> {
  SignalingEndpointCopyWith<$R, SignalingEndpoint, $Out> get $asSignalingEndpoint => $base.as(
        (v, t, t2) => _SignalingEndpointCopyWithImpl<$R, $Out>(v, t, t2),
      );
}

abstract class SignalingEndpointCopyWith<$R, $In extends SignalingEndpoint, $Out> implements DeviceEndpointCopyWith<$R, $In, $Out> {
  @override
  $R call({String? signalingId, String? signalingServer, String? serverToken});
  SignalingEndpointCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _SignalingEndpointCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, SignalingEndpoint, $Out>
    implements SignalingEndpointCopyWith<$R, SignalingEndpoint, $Out> {
  _SignalingEndpointCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SignalingEndpoint> $mapper = SignalingEndpointMapper.ensureInitialized();
  @override
  $R call({
    String? signalingId,
    String? signalingServer,
    String? serverToken,
  }) =>
      $apply(
        FieldCopyWithData({
          if (signalingId != null) #signalingId: signalingId,
          if (signalingServer != null) #signalingServer: signalingServer,
          if (serverToken != null) #serverToken: serverToken,
        }),
      );
  @override
  SignalingEndpoint $make(CopyWithData data) => SignalingEndpoint(
        signalingId: data.get(#signalingId, or: $value.signalingId),
        signalingServer: data.get(#signalingServer, or: $value.signalingServer),
        serverToken: data.get(#serverToken, or: $value.serverToken),
      );

  @override
  SignalingEndpointCopyWith<$R2, SignalingEndpoint, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) =>
      _SignalingEndpointCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class DeviceMapper extends ClassMapperBase<Device> {
  DeviceMapper._();

  static DeviceMapper? _instance;
  static DeviceMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DeviceMapper._());
      DeviceTypeMapper.ensureInitialized();
      DeviceEndpointMapper.ensureInitialized();
      DiscoveryMethodMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'Device';

  static String _$version(Device v) => v.version;
  static const Field<Device, String> _f$version = Field('version', _$version);
  static String _$alias(Device v) => v.alias;
  static const Field<Device, String> _f$alias = Field('alias', _$alias);
  static String? _$deviceModel(Device v) => v.deviceModel;
  static const Field<Device, String> _f$deviceModel = Field(
    'deviceModel',
    _$deviceModel,
  );
  static DeviceType _$deviceType(Device v) => v.deviceType;
  static const Field<Device, DeviceType> _f$deviceType = Field(
    'deviceType',
    _$deviceType,
  );
  static bool _$download(Device v) => v.download;
  static const Field<Device, bool> _f$download = Field('download', _$download);
  static Set<DeviceEndpoint> _$endpoints(Device v) => v.endpoints;
  static const Field<Device, Set<DeviceEndpoint>> _f$endpoints = Field(
    'endpoints',
    _$endpoints,
  );
  static Set<DiscoveryMethod> _$discoveryMethods(Device v) => v.discoveryMethods;
  static const Field<Device, Set<DiscoveryMethod>> _f$discoveryMethods = Field(
    'discoveryMethods',
    _$discoveryMethods,
  );

  @override
  final MappableFields<Device> fields = const {
    #version: _f$version,
    #alias: _f$alias,
    #deviceModel: _f$deviceModel,
    #deviceType: _f$deviceType,
    #download: _f$download,
    #endpoints: _f$endpoints,
    #discoveryMethods: _f$discoveryMethods,
  };

  static Device _instantiate(DecodingData data) {
    return Device(
      version: data.dec(_f$version),
      alias: data.dec(_f$alias),
      deviceModel: data.dec(_f$deviceModel),
      deviceType: data.dec(_f$deviceType),
      download: data.dec(_f$download),
      endpoints: data.dec(_f$endpoints),
      discoveryMethods: data.dec(_f$discoveryMethods),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Device fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Device>(map);
  }

  static Device deserialize(String json) {
    return ensureInitialized().decodeJson<Device>(json);
  }
}

mixin DeviceMappable {
  String serialize() {
    return DeviceMapper.ensureInitialized().encodeJson<Device>(this as Device);
  }

  Map<String, dynamic> toJson() {
    return DeviceMapper.ensureInitialized().encodeMap<Device>(this as Device);
  }

  DeviceCopyWith<Device, Device, Device> get copyWith => _DeviceCopyWithImpl<Device, Device>(this as Device, $identity, $identity);
  @override
  String toString() {
    return DeviceMapper.ensureInitialized().stringifyValue(this as Device);
  }

  @override
  bool operator ==(Object other) {
    return DeviceMapper.ensureInitialized().equalsValue(this as Device, other);
  }

  @override
  int get hashCode {
    return DeviceMapper.ensureInitialized().hashValue(this as Device);
  }
}

extension DeviceValueCopy<$R, $Out> on ObjectCopyWith<$R, Device, $Out> {
  DeviceCopyWith<$R, Device, $Out> get $asDevice => $base.as((v, t, t2) => _DeviceCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class DeviceCopyWith<$R, $In extends Device, $Out> implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? version,
    String? alias,
    String? deviceModel,
    DeviceType? deviceType,
    bool? download,
    Set<DeviceEndpoint>? endpoints,
    Set<DiscoveryMethod>? discoveryMethods,
  });
  DeviceCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _DeviceCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, Device, $Out> implements DeviceCopyWith<$R, Device, $Out> {
  _DeviceCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Device> $mapper = DeviceMapper.ensureInitialized();
  @override
  $R call({
    String? version,
    String? alias,
    Object? deviceModel = $none,
    DeviceType? deviceType,
    bool? download,
    Set<DeviceEndpoint>? endpoints,
    Set<DiscoveryMethod>? discoveryMethods,
  }) =>
      $apply(
        FieldCopyWithData({
          if (version != null) #version: version,
          if (alias != null) #alias: alias,
          if (deviceModel != $none) #deviceModel: deviceModel,
          if (deviceType != null) #deviceType: deviceType,
          if (download != null) #download: download,
          if (endpoints != null) #endpoints: endpoints,
          if (discoveryMethods != null) #discoveryMethods: discoveryMethods,
        }),
      );
  @override
  Device $make(CopyWithData data) => Device(
        version: data.get(#version, or: $value.version),
        alias: data.get(#alias, or: $value.alias),
        deviceModel: data.get(#deviceModel, or: $value.deviceModel),
        deviceType: data.get(#deviceType, or: $value.deviceType),
        download: data.get(#download, or: $value.download),
        endpoints: data.get(#endpoints, or: $value.endpoints),
        discoveryMethods: data.get(#discoveryMethods, or: $value.discoveryMethods),
      );

  @override
  DeviceCopyWith<$R2, Device, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) => _DeviceCopyWithImpl<$R2, $Out2>($value, $cast, t);
}
