// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'signaling_provider.dart';

class SignalingStateMapper extends ClassMapperBase<SignalingState> {
  SignalingStateMapper._();

  static SignalingStateMapper? _instance;
  static SignalingStateMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = SignalingStateMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'SignalingState';

  static List<String> _$signalingServers(SignalingState v) =>
      v.signalingServers;
  static const Field<SignalingState, List<String>> _f$signalingServers = Field(
    'signalingServers',
    _$signalingServers,
  );
  static List<String> _$stunServers(SignalingState v) => v.stunServers;
  static const Field<SignalingState, List<String>> _f$stunServers = Field(
    'stunServers',
    _$stunServers,
  );
  static Map<String, LsSignalingConnection> _$connections(SignalingState v) =>
      v.connections;
  static const Field<SignalingState, Map<String, LsSignalingConnection>>
  _f$connections = Field('connections', _$connections);
  static Map<String, Set<String>> _$localIdentities(SignalingState v) =>
      v.localIdentities;
  static const Field<SignalingState, Map<String, Set<String>>>
  _f$localIdentities = Field('localIdentities', _$localIdentities);

  @override
  final MappableFields<SignalingState> fields = const {
    #signalingServers: _f$signalingServers,
    #stunServers: _f$stunServers,
    #connections: _f$connections,
    #localIdentities: _f$localIdentities,
  };

  static SignalingState _instantiate(DecodingData data) {
    return SignalingState(
      signalingServers: data.dec(_f$signalingServers),
      stunServers: data.dec(_f$stunServers),
      connections: data.dec(_f$connections),
      localIdentities: data.dec(_f$localIdentities),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static SignalingState fromJson(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<SignalingState>(map);
  }

  static SignalingState deserialize(String json) {
    return ensureInitialized().decodeJson<SignalingState>(json);
  }
}

mixin SignalingStateMappable {
  String serialize() {
    return SignalingStateMapper.ensureInitialized().encodeJson<SignalingState>(
      this as SignalingState,
    );
  }

  Map<String, dynamic> toJson() {
    return SignalingStateMapper.ensureInitialized().encodeMap<SignalingState>(
      this as SignalingState,
    );
  }

  SignalingStateCopyWith<SignalingState, SignalingState, SignalingState>
  get copyWith => _SignalingStateCopyWithImpl<SignalingState, SignalingState>(
    this as SignalingState,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return SignalingStateMapper.ensureInitialized().stringifyValue(
      this as SignalingState,
    );
  }

  @override
  bool operator ==(Object other) {
    return SignalingStateMapper.ensureInitialized().equalsValue(
      this as SignalingState,
      other,
    );
  }

  @override
  int get hashCode {
    return SignalingStateMapper.ensureInitialized().hashValue(
      this as SignalingState,
    );
  }
}

extension SignalingStateValueCopy<$R, $Out>
    on ObjectCopyWith<$R, SignalingState, $Out> {
  SignalingStateCopyWith<$R, SignalingState, $Out> get $asSignalingState =>
      $base.as((v, t, t2) => _SignalingStateCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class SignalingStateCopyWith<$R, $In extends SignalingState, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>
  get signalingServers;
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>> get stunServers;
  MapCopyWith<
    $R,
    String,
    LsSignalingConnection,
    ObjectCopyWith<$R, LsSignalingConnection, LsSignalingConnection>
  >
  get connections;
  MapCopyWith<
    $R,
    String,
    Set<String>,
    ObjectCopyWith<$R, Set<String>, Set<String>>
  >
  get localIdentities;
  $R call({
    List<String>? signalingServers,
    List<String>? stunServers,
    Map<String, LsSignalingConnection>? connections,
    Map<String, Set<String>>? localIdentities,
  });
  SignalingStateCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _SignalingStateCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, SignalingState, $Out>
    implements SignalingStateCopyWith<$R, SignalingState, $Out> {
  _SignalingStateCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<SignalingState> $mapper =
      SignalingStateMapper.ensureInitialized();
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>
  get signalingServers => ListCopyWith(
    $value.signalingServers,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(signalingServers: v),
  );
  @override
  ListCopyWith<$R, String, ObjectCopyWith<$R, String, String>>
  get stunServers => ListCopyWith(
    $value.stunServers,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(stunServers: v),
  );
  @override
  MapCopyWith<
    $R,
    String,
    LsSignalingConnection,
    ObjectCopyWith<$R, LsSignalingConnection, LsSignalingConnection>
  >
  get connections => MapCopyWith(
    $value.connections,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(connections: v),
  );
  @override
  MapCopyWith<
    $R,
    String,
    Set<String>,
    ObjectCopyWith<$R, Set<String>, Set<String>>
  >
  get localIdentities => MapCopyWith(
    $value.localIdentities,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(localIdentities: v),
  );
  @override
  $R call({
    List<String>? signalingServers,
    List<String>? stunServers,
    Map<String, LsSignalingConnection>? connections,
    Map<String, Set<String>>? localIdentities,
  }) => $apply(
    FieldCopyWithData({
      if (signalingServers != null) #signalingServers: signalingServers,
      if (stunServers != null) #stunServers: stunServers,
      if (connections != null) #connections: connections,
      if (localIdentities != null) #localIdentities: localIdentities,
    }),
  );
  @override
  SignalingState $make(CopyWithData data) => SignalingState(
    signalingServers: data.get(#signalingServers, or: $value.signalingServers),
    stunServers: data.get(#stunServers, or: $value.stunServers),
    connections: data.get(#connections, or: $value.connections),
    localIdentities: data.get(#localIdentities, or: $value.localIdentities),
  );

  @override
  SignalingStateCopyWith<$R2, SignalingState, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _SignalingStateCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

