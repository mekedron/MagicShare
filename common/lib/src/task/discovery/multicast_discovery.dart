import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:common/api_route_builder.dart';
import 'package:common/constants.dart';
import 'package:common/isolate.dart';
import 'package:common/model/device.dart';
import 'package:common/model/dto/multicast_dto.dart';
import 'package:common/model/dto/register_dto.dart';
import 'package:common/src/isolate/child/http_provider.dart';
import 'package:common/util/network_interfaces.dart';
import 'package:common/util/sleep.dart';
import 'package:logging/logging.dart';
import 'package:refena/refena.dart';

final _logger = Logger('Multicast');

final multicastDiscoveryProvider = Provider((ref) {
  return MulticastService(ref);
});

class MulticastService {
  MulticastService(this._ref);

  final Ref _ref;
  Completer<void> _cancelCompleter = Completer();
  bool _listening = false;

  /// Binds the UDP port and listen to UDP multicast packages
  /// It will automatically answer announcement messages
  Stream<MulticastEvent> startListener() async* {
    if (_listening) {
      _logger.info('Already listening to multicast');
      return;
    }

    _listening = true;

    while (true) {
      final streamController = StreamController<MulticastEvent>();
      final syncState = _ref.read(syncProvider);

      final sockets = await _getSockets(
        whitelist: syncState.networkWhitelist,
        blacklist: syncState.networkBlacklist,
        multicastGroup: syncState.multicastGroup,
        port: syncState.multicastPort,
      );
      for (final socket in sockets) {
        socket.socket.listen((_) {
          final datagram = socket.socket.receive();
          if (datagram == null) {
            return;
          }

          try {
            final dto = MulticastDto.fromJson(jsonDecode(utf8.decode(datagram.data)));
            if (dto.fingerprint == syncState.securityContext.certificateHash) {
              return;
            }

            final shortFp = dto.fingerprint.length <= 8 ? dto.fingerprint : dto.fingerprint.substring(0, 8);

            // MagicShare goodbye: peer is announcing its imminent
            // disappearance. Surface it as a [MulticastGoodbye] event
            // and skip both the toDevice conversion and the auto-
            // answer path — answering a goodbye would defeat the
            // point of the signal.
            if (dto.goodbye == true) {
              _logger.info('[presence:udp-recv] goodbye from ${datagram.address.address} fp=$shortFp alias=${dto.alias}');
              streamController.add(MulticastGoodbye(dto.fingerprint));
              return;
            }

            final ip = datagram.address.address;
            _logger.info(
              '[presence:udp-recv] ${dto.announce == true || dto.announcement == true ? 'announce' : 'response'} from $ip fp=$shortFp alias=${dto.alias} announcedPort=${dto.port}',
            );
            Device peer = dto.toDevice(ip, syncState.port, syncState.protocol == ProtocolType.https);

            // Dev-mode loopback rewrite. The qemu emulator's outbound
            // multicast arrives at the host with source IP rewritten
            // to one of our own LAN IPs; the iOS Simulator's
            // announces look the same because it shares the host
            // loopback. Without this rewrite, peer.ip points at our
            // own listener and TCP `_answerAnnouncement` / direct
            // `prepareUpload` loops back to ourselves (412
            // self-fingerprint).
            //
            // Port-aware:
            //   * Announces matching our own multicast port (LocalSend
            //     default 53317) come from a co-located peer running
            //     on the same well-known port — overwhelmingly the
            //     Android emulator inside qemu — so route via the
            //     adb-forward tunnel (devLoopbackRewritePort).
            //   * Announces on a different port (e.g. iOS Simulator
            //     bound to 53319 via the LOCALSEND_PORT override)
            //     come from a same-loopback peer reachable directly
            //     at that port — keep the announced port, only
            //     rewrite the host.
            final rewriteHost = syncState.devLoopbackRewriteHost;
            final rewritePort = syncState.devLoopbackRewritePort;
            if (rewriteHost != null && rewritePort != null && syncState.ownLocalIps.contains(ip)) {
              if (peer.port == syncState.multicastPort) {
                _logger.info('[presence:udp-recv] REWRITE loopback (own-port match) → $rewriteHost:$rewritePort');
                peer = peer.copyWith(ip: rewriteHost, port: rewritePort);
              } else {
                _logger.info('[presence:udp-recv] REWRITE loopback (foreign-port) → $rewriteHost:${peer.port}');
                peer = peer.copyWith(ip: rewriteHost);
              }
            }

            streamController.add(MulticastDiscovered(peer));
            if ((dto.announcement == true || dto.announce == true) && syncState.serverRunning) {
              // only respond when server is running. Uses the
              // (possibly rewritten) peer so the TCP register hits
              // the right host instead of looping back to us.
              // ignore: discarded_futures
              _answerAnnouncement(peer);
            }
          } catch (e) {
            _logger.warning('Could not parse multicast message', e);
          }
        });
        _logger.info(
          'Bind UDP multicast port (ip: ${socket.interface.addresses.map((a) => a.address).toList()}, group: ${syncState.multicastGroup}, port: ${syncState.multicastPort})',
        );
      }

      // Tell everyone in the network that I am online
      sendAnnouncement(); // ignore: unawaited_futures

      _cancelCompleter = Completer();

      // ignore: unawaited_futures
      _cancelCompleter.future.then((_) {
        // ignore: discarded_futures
        streamController.close();
        for (final socket in sockets) {
          socket.socket.close();
        }
      });

      yield* streamController.stream;

      // streamController is closed because of cancel
      // wait for resources to be released (it works without on macOS, but who knows)
      await sleepAsync(500);
    }
  }

  void restartListener() {
    _cancelCompleter.complete();
  }

  /// Sends an announcement which triggers a response on every LocalSend member of the network.
  Future<void> sendAnnouncement() async {
    final syncState = _ref.read(syncProvider);
    final sockets = await _getSockets(
      whitelist: syncState.networkWhitelist,
      blacklist: syncState.networkBlacklist,
      multicastGroup: syncState.multicastGroup,
    );
    final dto = _getMulticastDto(announcement: true);
    final shortFp = syncState.securityContext.certificateHash.length <= 8
        ? syncState.securityContext.certificateHash
        : syncState.securityContext.certificateHash.substring(0, 8);
    for (final wait in [100, 500, 2000]) {
      await sleepAsync(wait);

      _logger.info('[presence:udp-send] announce wait=${wait}ms fp=$shortFp socketCount=${sockets.length}');
      for (final socket in sockets) {
        try {
          socket.socket.send(dto, InternetAddress(syncState.multicastGroup), syncState.multicastPort);
          socket.socket.close();
        } catch (e) {
          _logger.warning('Could not send multicast message', e);
        }
      }
    }
  }

  /// Sends a goodbye packet so peers can drop this device from their
  /// nearby list immediately, without waiting for the LAN-side TTL.
  /// Wired to mobile lifecycle paused / hidden in the app. Sent as a
  /// short burst — UDP is unreliable and a single packet on the way
  /// out tends to be the *least* likely to arrive (the socket may be
  /// torn down before it leaves the host).
  Future<void> sendGoodbye() async {
    final syncState = _ref.read(syncProvider);
    final sockets = await _getSockets(
      whitelist: syncState.networkWhitelist,
      blacklist: syncState.networkBlacklist,
      multicastGroup: syncState.multicastGroup,
    );
    final dto = _getMulticastDto(announcement: false, goodbye: true);
    final shortFp = syncState.securityContext.certificateHash.length <= 8
        ? syncState.securityContext.certificateHash
        : syncState.securityContext.certificateHash.substring(0, 8);
    for (var i = 0; i < 3; i++) {
      _logger.info('[presence:udp-send] goodbye burst=${i + 1}/3 fp=$shortFp socketCount=${sockets.length}');
      for (final socket in sockets) {
        try {
          socket.socket.send(dto, InternetAddress(syncState.multicastGroup), syncState.multicastPort);
        } catch (e) {
          _logger.warning('Could not send multicast goodbye', e);
        }
      }
      await sleepAsync(50);
    }
    for (final socket in sockets) {
      socket.socket.close();
    }
  }

  /// Responds to an announcement.
  Future<void> _answerAnnouncement(Device peer) async {
    try {
      // Answer with TCP
      await _ref.read(httpProvider).discovery.post(
            uri: ApiRoute.register.target(peer),
            json: _getRegisterDto().toJson(),
          );
      _logger.info('Respond to announcement of ${peer.alias} (${peer.ip}, model: ${peer.deviceModel}) via TCP');
    } catch (e) {
      // Fallback: Answer with UDP
      final syncState = _ref.read(syncProvider);
      final sockets = await _getSockets(
        whitelist: syncState.networkWhitelist,
        blacklist: syncState.networkBlacklist,
        multicastGroup: syncState.multicastGroup,
      );
      final dto = _getMulticastDto(announcement: false);
      for (final socket in sockets) {
        try {
          socket.socket.send(dto, InternetAddress(syncState.multicastGroup), syncState.multicastPort);
          socket.socket.close();
        } catch (e) {
          _logger.warning('Could not send multicast message', e);
        }
      }
      _logger.info('Respond to announcement of ${peer.alias} (${peer.ip}, model: ${peer.deviceModel}) with UDP because TCP failed');
    }
  }

  /// Returns the MulticastDto of this device in bytes.
  List<int> _getMulticastDto({required bool announcement, bool goodbye = false}) {
    final syncState = _ref.read(syncProvider);
    final dto = MulticastDto(
      alias: syncState.alias,
      version: protocolVersion,
      deviceModel: syncState.deviceInfo.deviceModel,
      deviceType: syncState.deviceInfo.deviceType,
      fingerprint: syncState.securityContext.certificateHash,
      port: syncState.port,
      protocol: syncState.protocol,
      download: syncState.download,
      announcement: announcement,
      announce: announcement,
      goodbye: goodbye ? true : null,
    );
    return utf8.encode(jsonEncode(dto.toJson()));
  }

  RegisterDto _getRegisterDto() {
    final syncState = _ref.read(syncProvider);
    return RegisterDto(
      alias: syncState.alias,
      version: protocolVersion,
      deviceModel: syncState.deviceInfo.deviceModel,
      deviceType: syncState.deviceInfo.deviceType,
      fingerprint: syncState.securityContext.certificateHash,
      port: syncState.port,
      protocol: syncState.protocol,
      download: syncState.download,
    );
  }
}

class _SocketResult {
  final NetworkInterface interface;
  final RawDatagramSocket socket;

  _SocketResult(this.interface, this.socket);
}

Future<List<_SocketResult>> _getSockets({
  required List<String>? whitelist,
  required List<String>? blacklist,
  required String multicastGroup,
  int? port,
}) async {
  final interfaces = await getNetworkInterfaces(
    whitelist: whitelist,
    blacklist: blacklist,
  );
  final sockets = <_SocketResult>[];
  for (final interface in interfaces) {
    try {
      // `reusePort: true` so multiple processes on the same host (the
      // dev setup runs macOS + iOS Simulator + Android emulator side
      // by side) can each bind the same multicast port. Without this,
      // the second process fails with EADDRINUSE — the canonical
      // "iPhone sees nobody" symptom in run-dev.sh: macOS binds the
      // multicast UDP socket first, iOS Simulator's bind fails, and
      // the iOS multicast listener never starts.
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port ?? 0,
        reusePort: true,
      );
      socket.joinMulticast(InternetAddress(multicastGroup), interface);
      sockets.add(_SocketResult(interface, socket));
    } catch (e) {
      _logger.warning(
        'Could not bind UDP multicast port (ip: ${interface.addresses.map((a) => a.address).toList()}, group: $multicastGroup, port: $port)',
        e,
      );
    }
  }

  return sockets;
}
