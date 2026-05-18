/// The protocol version.
///
/// Version table:
/// Protocols | App (Official implementation)
/// ----------|------------------------------
/// 1.0       | 1.0.0 - 1.8.0
/// 1.0, 2.0  | 1.9.0 - 1.14.0
/// 1.0, 2.1  | 1.15.0 - 1.17.0
/// 2.1       | 1.18.0
const protocolVersion = '2.1';

/// Assumed protocol version of peers for first handshake.
/// Generally this should be slightly lower than the current protocol version.
const peerProtocolVersion = '1.0';

/// The protocol version when no version is specified.
/// Prior v2, the protocol version was not specified.
const fallbackProtocolVersion = '1.0';

/// The default http server port and
/// and multicast port.
const defaultPort = 53317;

/// The default discovery timeout in milliseconds.
/// This is the time the discovery server waits for responses.
/// If no response is received within this time, the target server is unavailable.
///
/// 500 ms is too aggressive for iOS HTTPS handshakes against a self-signed
/// cert — the receiver can easily exceed the budget on first contact, leaving
/// the device discoverable via signaling but not via LAN HTTP. 2000 ms keeps
/// the subnet scan bounded (256 IPs / 50-way concurrency ≈ ~10 s worst case)
/// while reliably catching slow iOS responders.
const defaultDiscoveryTimeout = 2000;

/// The default multicast group should be 224.0.0.0/24
/// because on some Android devices this is the only IP range
/// that can receive UDP multicast messages.
const defaultMulticastGroup = '224.0.0.167';
