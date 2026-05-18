import 'dart:async';

import 'package:common/constants.dart';
import 'package:common/model/device.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:flutter/foundation.dart';
import 'package:magicshare_app/provider/device_info_provider.dart';
import 'package:magicshare_app/provider/favorites_provider.dart';
import 'package:magicshare_app/provider/network/nearby_devices_provider.dart';
import 'package:magicshare_app/provider/network/scan_facade.dart';
import 'package:magicshare_app/provider/network/webrtc/webrtc_receiver.dart';
import 'package:magicshare_app/provider/persistence_provider.dart';
import 'package:magicshare_app/provider/security_provider.dart';
import 'package:magicshare_app/provider/settings_provider.dart';
import 'package:magicshare_app/rust/api/crypto.dart' as crypto;
import 'package:magicshare_app/rust/api/model.dart' as rust;
import 'package:magicshare_app/rust/api/webrtc.dart';
import 'package:refena_flutter/refena_flutter.dart';

part 'signaling_provider.mapper.dart';

@MappableClass()
class SignalingState with SignalingStateMappable {
  final List<String> signalingServers;
  final List<String> stunServers;
  final Map<String, LsSignalingConnection> connections;

  /// Per signaling server, the set of `(signalingId, serverToken)` values
  /// this client has received in its own [WsServerMessage_Hello.client]
  /// response. Used to drop peer-discovery events that refer back to the
  /// local device — the equivalent of LAN multicast's cert-hash self-filter.
  ///
  /// signalingIds (UUIDs) and serverTokens (sha256.…) have disjoint formats,
  /// so we keep them in one set and check incoming endpoints against both.
  final Map<String, Set<String>> localIdentities;

  SignalingState({
    required this.signalingServers,
    required this.stunServers,
    required this.connections,
    required this.localIdentities,
  });
}

final signalingProvider = ReduxProvider<SignalingService, SignalingState>((ref) {
  return SignalingService(
    persistence: ref.read(persistenceProvider),
  );
});

class SignalingService extends ReduxNotifier<SignalingState> {
  final PersistenceService _persistence;

  SignalingService({
    required PersistenceService persistence,
  }) : _persistence = persistence;

  @override
  SignalingState init() {
    return SignalingState(
      signalingServers: _persistence.getSignalingServers() ?? ['wss://public.localsend.org/v1/ws'],
      stunServers: _persistence.getStunServers() ?? ['stun:stun.localsend.org:5349'],
      connections: {},
      localIdentities: {},
    );
  }
}

class SetupSignalingConnection extends ReduxAction<SignalingService, SignalingState> with GlobalActions {
  @override
  SignalingState reduce() {
    for (final signalingServer in state.signalingServers) {
      if (state.connections.containsKey(signalingServer)) {
        // Already connected. _RemoveConnectionAction clears it on disconnect,
        // so this guard keeps HomePage rebuilds from spawning duplicates.
        continue;
      }
      // ignore: discarded_futures
      global.dispatchAsync(_SetupSignalingConnection(signalingServer: signalingServer));
    }
    return state;
  }
}

/// Starts an endless running action.
class _SetupSignalingConnection extends AsyncGlobalAction {
  final String signalingServer;

  _SetupSignalingConnection({required this.signalingServer});

  @override
  Future<void> reduce() async {
    final settings = ref.read(settingsProvider);
    final deviceInfo = ref.read(deviceInfoProvider);

    // TODO: Use persistent key
    final key = await crypto.generateKeyPair();
    if (kDebugMode) {
      print('private key: ${key.privateKey}');
    }

    LsSignalingConnection? connection;
    final stream = connect(
      uri: 'wss://public.localsend.org/v1/ws',
      info: ProposingClientInfo(
        alias: settings.alias,
        version: protocolVersion,
        deviceModel: deviceInfo.deviceModel,
        deviceType: deviceInfo.deviceType.toRustDeviceType(),
      ),
      privateKey: key.privateKey,
      onConnection: (c) {
        connection = c;

        ref
            .redux(signalingProvider)
            .dispatch(
              _SetConnectionAction(
                signalingServer: signalingServer,
                connection: c,
              ),
            );
      },
    );

    try {
      await for (final message in stream) {
        switch (message) {
          case WsServerMessage_Hello():
            ref
                .redux(signalingProvider)
                .dispatch(
                  _RegisterLocalIdentityAction(
                    signalingServer: signalingServer,
                    signalingId: message.client.id.uuid,
                    serverToken: message.client.token,
                  ),
                );
            final selfId = message.client.id.uuid;
            final selfToken = message.client.token;
            final localIdentities = ref.read(signalingProvider).localIdentities[signalingServer] ?? const <String>{};
            var anyPeerLacksLan = false;
            for (final d in message.peers) {
              if (d.id.uuid == selfId || d.token == selfToken) {
                // Server occasionally echoes our own ClientInfo in peers —
                // e.g. when a previous connection from the same NAT'd IP
                // hasn't been torn down yet. Drop it before it pollutes
                // signalingDevices.
                continue;
              }
              ref
                  .redux(nearbyDevicesProvider)
                  .dispatch(
                    RegisterSignalingDeviceAction(
                      d.toDevice(signalingServer),
                      localIdentities: localIdentities,
                    ),
                  );
              if (!_hasLanTwin(ref, d)) {
                anyPeerLacksLan = true;
              }
            }
            if (anyPeerLacksLan) {
              _kickOffLanRescan(ref);
            }
            break;
          case WsServerMessage_Join(peer: final peer):
          case WsServerMessage_Update(peer: final peer):
            ref
                .redux(nearbyDevicesProvider)
                .dispatch(
                  RegisterSignalingDeviceAction(
                    peer.toDevice(signalingServer),
                    localIdentities: ref.read(signalingProvider).localIdentities[signalingServer] ?? const <String>{},
                  ),
                );
            if (message is WsServerMessage_Join && !_hasLanTwin(ref, peer)) {
              _kickOffLanRescan(ref);
            }
            break;
          case WsServerMessage_Left():
            ref
                .redux(nearbyDevicesProvider)
                .dispatch(
                  UnregisterSignalingDeviceAction(
                    message.peerId.uuid,
                  ),
                );
            break;
          case WsServerMessage_Offer():
            final provider = ReduxProvider<WebRTCReceiveService, WebRTCReceiveState>((ref) {
              return WebRTCReceiveService(
                signalingServer: signalingServer,
                stunServers: ref.read(signalingProvider).stunServers,
                connection: connection!,
                offer: message.field0,
                settings: ref.read(settingsProvider),
                favorites: ref.read(favoritesProvider),
                key: ref.read(securityProvider),
              );
            });

            await ref.redux(provider).dispatchAsync(AcceptOfferAction());
            break;
          case WsServerMessage_Answer():
          case WsServerMessage_Error():
        }
      }
    } finally {
      ref.redux(signalingProvider).dispatch(_RemoveConnectionAction(signalingServer: signalingServer));
    }

    return state;
  }
}

class _SetConnectionAction extends ReduxAction<SignalingService, SignalingState> {
  final String signalingServer;
  final LsSignalingConnection connection;

  _SetConnectionAction({
    required this.signalingServer,
    required this.connection,
  });

  @override
  SignalingState reduce() {
    return state.copyWith(
      connections: {
        ...state.connections,
        signalingServer: connection,
      },
    );
  }
}

class _RemoveConnectionAction extends ReduxAction<SignalingService, SignalingState> {
  final String signalingServer;

  _RemoveConnectionAction({required this.signalingServer});

  @override
  SignalingState reduce() {
    return state.copyWith(
      connections: {
        for (final entry in state.connections.entries)
          if (entry.key != signalingServer) entry.key: entry.value,
      },
      localIdentities: {
        for (final entry in state.localIdentities.entries)
          if (entry.key != signalingServer) entry.key: entry.value,
      },
    );
  }
}

class _RegisterLocalIdentityAction extends ReduxAction<SignalingService, SignalingState> {
  final String signalingServer;
  final String signalingId;
  final String serverToken;

  _RegisterLocalIdentityAction({
    required this.signalingServer,
    required this.signalingId,
    required this.serverToken,
  });

  @override
  SignalingState reduce() {
    final existing = state.localIdentities[signalingServer] ?? const <String>{};
    return state.copyWith(
      localIdentities: {
        ...state.localIdentities,
        signalingServer: {...existing, signalingId, serverToken},
      },
    );
  }
}

/// True when [peer] has an HTTP-discovered twin (same identity tuple) in
/// [NearbyDevicesService.state.devices]. Signaling tokens and LAN cert hashes
/// share no value space, so we fall back to the user-visible identity tuple —
/// the same heuristic the merge in `NearbyDevicesState.allDevices` uses.
bool _hasLanTwin(Ref ref, ClientInfo peer) {
  final lanDevices = ref.read(nearbyDevicesProvider).devices.values;
  for (final lan in lanDevices) {
    if (lan.alias == peer.alias && lan.deviceModel == peer.deviceModel) {
      return true;
    }
  }
  return false;
}

/// Schedule a forced subnet scan when signaling has surfaced a peer that the
/// LAN hasn't seen yet. `forceLegacy: true` bypasses the early-return that
/// `StartSmartScan` does when devices is already non-empty — without it, we'd
/// never find the new peer's HTTPS endpoint if another LAN device is already
/// in the list. The fire-and-forget pattern is intentional: the signaling
/// stream loop must not block on scan completion.
void _kickOffLanRescan(Ref ref) {
  // ignore: discarded_futures
  ref.global.dispatchAsync(StartSmartScan(forceLegacy: true));
}

extension ClientInfoExt on ClientInfo {
  Device toDevice(String signalingServer) {
    return Device(
      version: version,
      alias: alias,
      deviceModel: deviceModel,
      deviceType: deviceType?.toDeviceType() ?? DeviceType.desktop,
      download: false,
      endpoints: {
        SignalingEndpoint(
          signalingId: id.uuid,
          signalingServer: signalingServer,
          serverToken: token,
        ),
      },
      discoveryMethods: {
        SignalingDiscovery(
          signalingServer: signalingServer,
        ),
      },
    );
  }
}

extension on rust.DeviceType {
  DeviceType toDeviceType() {
    return switch (this) {
      rust.DeviceType.mobile => DeviceType.mobile,
      rust.DeviceType.desktop => DeviceType.desktop,
      rust.DeviceType.web => DeviceType.web,
      rust.DeviceType.headless => DeviceType.headless,
      rust.DeviceType.server => DeviceType.server,
    };
  }
}

extension on DeviceType {
  rust.DeviceType toRustDeviceType() {
    return switch (this) {
      DeviceType.mobile => rust.DeviceType.mobile,
      DeviceType.desktop => rust.DeviceType.desktop,
      DeviceType.web => rust.DeviceType.web,
      DeviceType.headless => rust.DeviceType.headless,
      DeviceType.server => rust.DeviceType.server,
    };
  }
}
