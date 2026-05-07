import 'dart:convert';
import 'dart:typed_data';

/// Pairing payload format.
///
/// One self-describing byte blob carries everything a joining device
/// needs to pair off the QR / manual code alone.
///
/// **v1** (legacy — still decodable for back-compat):
///
///   version=1(1) | tokenLen(1) | tokenId(N) |
///   addrFamily(1) | ipBytes(4) | port(2, BE) |
///   pubkeyLen(1) | pubkey(33) |
///   crc8(1)
///
/// **v2** (current — what `encodePairingPayload` always emits):
///
///   version=2(1) | tokenLen(1) | tokenId(N) |
///   addrCount(1) | [addrFamily(1) | ipBytes(4)](xAddrCount) |
///   port(2, BE) | pubkeyLen(1) | pubkey(33) |
///   crc8(1)
///
/// v2 lets the issuer advertise multiple LAN addresses for a single
/// pairing session — required when one issuer needs to be reachable
/// to joiners on different network paths simultaneously (e.g. macOS
/// host advertising `127.0.0.1` for an Android emulator joiner that
/// reaches it via `adb reverse`, AND its real `192.168.x.x` for a
/// physical iPhone joiner on the same Wi-Fi). The joiner races
/// connect attempts across the listed addresses and uses the first
/// one that succeeds.
///
/// The same blob is encoded two ways:
///
///   * **QR form** — `magicshare-pair:<base64url(payload)>`. Some QR
///     scanners auto-route URI-style payloads via the OS deep-link
///     dispatcher; that's why we carry a scheme even though the QR
///     itself is captured in-app.
///   * **Manual form** — Crockford Base32 of the payload, grouped in
///     4-char chunks separated by `-` for legibility. Crockford's
///     ambiguity-free alphabet (no I/L/O/U) survives users squinting
///     at a screen and re-typing.
///
/// A 1-byte CRC-8 (poly 0x07, init 0x00) trails the payload so a
/// single-character typo is caught with a clear "you mistyped" surface
/// instead of falling through to an opaque "join token not found"
/// cloud error.
///
/// IPv6 is intentionally out of scope: pairing happens on the same
/// Wi-Fi LAN, which in practice is IPv4 99% of the time. Adding IPv6
/// without bumping `version` would silently break older installs that
/// decode the payload.

const int pairingPayloadVersionV1 = 1;
const int pairingPayloadVersionV2 = 2;
const int _addrFamilyIPv4 = 4;
const int _ipv4LengthBytes = 4;
const int _portLengthBytes = 2;
const int _crcLengthBytes = 1;
const int _maxPubkeyLengthBytes = 64;
const int _maxTokenLengthBytes = 96;

/// Cap on the number of LAN addresses per payload. Bounds the QR /
/// manual-code size and prevents an attacker who can poison the
/// issuer's interface list from inflating the blob.
const int kMaxPairingAddresses = 4;

/// URI scheme used by the QR form. Includes the trailing `:` so the
/// caller doesn't accidentally double-up.
const String pairingUriScheme = 'magicshare-pair:';

/// Crockford Base32 alphabet — no I, L, O, U (the latter excluded for
/// "obscenity-prevention" per the original spec). Case-insensitive on
/// decode; we always emit uppercase.
const String _crockfordAlphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

class PairingPayload {
  PairingPayload({
    required this.tokenId,
    required this.issuerLanAddresses,
    required this.issuerLanPort,
    required this.issuerPubKeyCompressed,
    this.version = pairingPayloadVersionV2,
  });

  /// Same shape the cloud function expects on `previewJoinToken` /
  /// `joinNetwork` — opaque base64url string minted server-side. We
  /// pack and unpack it as ASCII bytes so the codec stays
  /// agnostic to a future backend change.
  final String tokenId;

  /// Ordered list of IPv4 dotted-quad addresses the joiner should try
  /// to reach the issuer on. Order matters: the issuer puts its
  /// preferred reachability path first (e.g. an `adb reverse`
  /// loopback override) so the joiner's race terminates on the
  /// most-likely-fast path. IPv6 is intentionally not supported.
  final List<String> issuerLanAddresses;

  /// 1..65535. The issuer's ephemeral pairing-LAN-server port; the
  /// joiner connects here over plain TCP / HTTP after `joinNetwork`
  /// succeeds.
  final int issuerLanPort;

  /// SEC1-compressed P-256 public key (33 bytes for P-256). Other
  /// pubkey lengths are accepted on decode but the codec asserts the
  /// length-byte matches the supplied bytes.
  final Uint8List issuerPubKeyCompressed;

  final int version;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PairingPayload &&
          tokenId == other.tokenId &&
          _listEquals(issuerLanAddresses, other.issuerLanAddresses) &&
          issuerLanPort == other.issuerLanPort &&
          version == other.version &&
          _bytesEqual(issuerPubKeyCompressed, other.issuerPubKeyCompressed);

  @override
  int get hashCode => Object.hash(
    tokenId,
    Object.hashAll(issuerLanAddresses),
    issuerLanPort,
    version,
    Object.hashAll(issuerPubKeyCompressed),
  );

  @override
  String toString() =>
      'PairingPayload(tokenId: $tokenId, issuerLanAddresses: $issuerLanAddresses, '
      'issuerLanPort: $issuerLanPort, version: $version, '
      'pubkeyLen: ${issuerPubKeyCompressed.length})';
}

enum PairingPayloadDecodeError {
  malformed,
  wrongLength,
  badChecksum,
  wrongVersion,
  badAlphabet,
  badAddress,
  badPort,
}

class PairingPayloadDecodeException implements Exception {
  PairingPayloadDecodeException(this.error, [this.detail]);
  final PairingPayloadDecodeError error;
  final String? detail;

  @override
  String toString() => detail == null ? 'PairingPayloadDecodeException: ${error.name}' : 'PairingPayloadDecodeException: ${error.name}: $detail';
}

// ---------------------------------------------------------------------------
// Binary form
// ---------------------------------------------------------------------------

Uint8List encodePairingPayload(PairingPayload payload) {
  // The encoder always emits v2. Callers cannot opt back into v1 —
  // the version field on PairingPayload is honoured on decode (so a
  // round-trip of a v1-decoded payload preserves its original
  // version byte for tests/debugging) but encode normalises forward.
  final tokenBytes = Uint8List.fromList(ascii.encode(payload.tokenId));
  if (tokenBytes.isEmpty || tokenBytes.length > _maxTokenLengthBytes) {
    throw ArgumentError('Token byte length out of range: ${tokenBytes.length}');
  }
  if (payload.issuerLanAddresses.isEmpty) {
    throw ArgumentError('Pairing payload must carry at least one LAN address');
  }
  if (payload.issuerLanAddresses.length > kMaxPairingAddresses) {
    throw ArgumentError(
      'Too many LAN addresses (${payload.issuerLanAddresses.length}, max $kMaxPairingAddresses)',
    );
  }
  final ipByteBlocks = payload.issuerLanAddresses.map(_encodeIPv4).toList(growable: false);
  if (payload.issuerLanPort < 1 || payload.issuerLanPort > 0xffff) {
    throw ArgumentError('Port out of range: ${payload.issuerLanPort}');
  }
  final pub = payload.issuerPubKeyCompressed;
  if (pub.isEmpty || pub.length > _maxPubkeyLengthBytes) {
    throw ArgumentError('Pubkey length out of range: ${pub.length}');
  }

  final builder = BytesBuilder()
    ..addByte(pairingPayloadVersionV2)
    ..addByte(tokenBytes.length)
    ..add(tokenBytes)
    ..addByte(ipByteBlocks.length);
  for (final ipBytes in ipByteBlocks) {
    builder
      ..addByte(_addrFamilyIPv4)
      ..add(ipBytes);
  }
  builder
    ..addByte((payload.issuerLanPort >> 8) & 0xff)
    ..addByte(payload.issuerLanPort & 0xff)
    ..addByte(pub.length)
    ..add(pub);

  final core = builder.toBytes();
  final crc = _crc8(core);
  final out = Uint8List(core.length + _crcLengthBytes);
  out.setRange(0, core.length, core);
  out[core.length] = crc;
  return out;
}

PairingPayload decodePairingPayload(Uint8List bytes) {
  if (bytes.length < 12) {
    throw PairingPayloadDecodeException(
      PairingPayloadDecodeError.wrongLength,
      'payload too short: ${bytes.length} bytes',
    );
  }
  final core = Uint8List.sublistView(bytes, 0, bytes.length - _crcLengthBytes);
  final crc = bytes[bytes.length - _crcLengthBytes];
  if (_crc8(core) != crc) {
    throw PairingPayloadDecodeException(
      PairingPayloadDecodeError.badChecksum,
      'CRC-8 mismatch',
    );
  }

  var i = 0;
  final version = core[i++];
  if (version != pairingPayloadVersionV1 && version != pairingPayloadVersionV2) {
    throw PairingPayloadDecodeException(
      PairingPayloadDecodeError.wrongVersion,
      'unknown version: $version',
    );
  }
  final tokenLen = core[i++];
  if (tokenLen == 0 || tokenLen > _maxTokenLengthBytes || i + tokenLen > core.length) {
    throw PairingPayloadDecodeException(
      PairingPayloadDecodeError.wrongLength,
      'token length out of range: $tokenLen',
    );
  }
  final tokenBytes = Uint8List.sublistView(core, i, i + tokenLen);
  i += tokenLen;
  final tokenId = ascii.decode(tokenBytes);

  if (i >= core.length) {
    throw PairingPayloadDecodeException(
      PairingPayloadDecodeError.wrongLength,
      'truncated before address section',
    );
  }

  final int addrCount;
  if (version == pairingPayloadVersionV2) {
    addrCount = core[i++];
    if (addrCount == 0 || addrCount > kMaxPairingAddresses) {
      throw PairingPayloadDecodeException(
        PairingPayloadDecodeError.wrongLength,
        'addrCount out of range: $addrCount',
      );
    }
  } else {
    // v1 had an implicit single-address layout with no count byte.
    addrCount = 1;
  }

  final addresses = <String>[];
  for (var n = 0; n < addrCount; n++) {
    if (i >= core.length) {
      throw PairingPayloadDecodeException(
        PairingPayloadDecodeError.wrongLength,
        'truncated before address family for entry $n',
      );
    }
    final addrFamily = core[i++];
    if (addrFamily != _addrFamilyIPv4) {
      throw PairingPayloadDecodeException(
        PairingPayloadDecodeError.malformed,
        'unsupported address family: $addrFamily (only IPv4 supported)',
      );
    }
    if (i + _ipv4LengthBytes > core.length) {
      throw PairingPayloadDecodeException(
        PairingPayloadDecodeError.wrongLength,
        'truncated IPv4 octets for entry $n',
      );
    }
    addresses.add('${core[i]}.${core[i + 1]}.${core[i + 2]}.${core[i + 3]}');
    i += _ipv4LengthBytes;
  }

  if (i + _portLengthBytes > core.length) {
    throw PairingPayloadDecodeException(
      PairingPayloadDecodeError.wrongLength,
      'truncated port',
    );
  }
  final port = (core[i] << 8) | core[i + 1];
  i += _portLengthBytes;
  if (port == 0) {
    throw PairingPayloadDecodeException(
      PairingPayloadDecodeError.badPort,
      'port may not be 0',
    );
  }

  if (i >= core.length) {
    throw PairingPayloadDecodeException(
      PairingPayloadDecodeError.wrongLength,
      'truncated before pubkey length',
    );
  }
  final pubLen = core[i++];
  if (pubLen == 0 || pubLen > _maxPubkeyLengthBytes || i + pubLen != core.length) {
    throw PairingPayloadDecodeException(
      PairingPayloadDecodeError.wrongLength,
      'pubkey length out of range or trailing bytes: $pubLen',
    );
  }
  final pub = Uint8List.fromList(core.sublist(i, i + pubLen));

  return PairingPayload(
    tokenId: tokenId,
    issuerLanAddresses: List.unmodifiable(addresses),
    issuerLanPort: port,
    issuerPubKeyCompressed: pub,
    version: version,
  );
}

// ---------------------------------------------------------------------------
// QR form (URI + base64url)
// ---------------------------------------------------------------------------

String encodePairingUri(PairingPayload payload) {
  final bytes = encodePairingPayload(payload);
  return '$pairingUriScheme${base64UrlEncode(bytes)}';
}

PairingPayload? tryDecodePairingUri(String input) {
  try {
    return decodePairingUri(input);
  } on PairingPayloadDecodeException {
    return null;
  } on FormatException {
    return null;
  }
}

PairingPayload decodePairingUri(String input) {
  var trimmed = input.trim();
  if (trimmed.toLowerCase().startsWith(pairingUriScheme)) {
    trimmed = trimmed.substring(pairingUriScheme.length);
  }
  // Tolerate either base64url or plain base64 (with `+`/`/`); some
  // platforms re-encode URIs.
  trimmed = trimmed.replaceAll('+', '-').replaceAll('/', '_');
  // base64UrlDecode requires correct padding length; pad up to a
  // multiple of 4 if the encoder dropped them.
  final padded = trimmed.padRight((trimmed.length + 3) & ~3, '=');
  final bytes = base64Url.decode(padded);
  return decodePairingPayload(Uint8List.fromList(bytes));
}

// ---------------------------------------------------------------------------
// Manual form (Crockford Base32, 4-char chunks)
// ---------------------------------------------------------------------------

String encodePairingManualCode(PairingPayload payload) {
  final bytes = encodePairingPayload(payload);
  final raw = _crockfordEncode(bytes);
  return _groupFour(raw);
}

PairingPayload? tryDecodePairingManualCode(String input) {
  try {
    return decodePairingManualCode(input);
  } on PairingPayloadDecodeException {
    return null;
  } on FormatException {
    return null;
  }
}

PairingPayload decodePairingManualCode(String input) {
  final normalized = _normalizeManualCode(input);
  final bytes = _crockfordDecode(normalized);
  return decodePairingPayload(bytes);
}

// ---------------------------------------------------------------------------
// Internals
// ---------------------------------------------------------------------------

Uint8List _encodeIPv4(String dotted) {
  final parts = dotted.split('.');
  if (parts.length != 4) {
    throw ArgumentError('Not an IPv4 address: $dotted');
  }
  final out = Uint8List(4);
  for (var i = 0; i < 4; i++) {
    final v = int.tryParse(parts[i]);
    if (v == null || v < 0 || v > 255) {
      throw ArgumentError('Invalid IPv4 octet: ${parts[i]}');
    }
    out[i] = v;
  }
  return out;
}

/// CRC-8/CCITT, polynomial 0x07, initial value 0x00, no XOR-out, no
/// reflection. Sufficient to flag a typo in a manual code.
int _crc8(Uint8List bytes) {
  var crc = 0;
  for (final b in bytes) {
    crc ^= b;
    for (var i = 0; i < 8; i++) {
      crc = ((crc & 0x80) != 0) ? ((crc << 1) ^ 0x07) & 0xff : (crc << 1) & 0xff;
    }
  }
  return crc;
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _listEquals(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _crockfordEncode(Uint8List bytes) {
  // Streamed 5-bits-per-symbol encoder. We build the full output
  // in one pass; bit-buffer holds the partial symbol carried
  // between input bytes.
  final sb = StringBuffer();
  var buffer = 0;
  var bits = 0;
  for (final byte in bytes) {
    buffer = (buffer << 8) | byte;
    bits += 8;
    while (bits >= 5) {
      bits -= 5;
      final idx = (buffer >> bits) & 0x1f;
      sb.write(_crockfordAlphabet[idx]);
    }
  }
  if (bits > 0) {
    final idx = (buffer << (5 - bits)) & 0x1f;
    sb.write(_crockfordAlphabet[idx]);
  }
  return sb.toString();
}

Uint8List _crockfordDecode(String input) {
  final bytes = <int>[];
  var buffer = 0;
  var bits = 0;
  for (var i = 0; i < input.length; i++) {
    final ch = input[i];
    final v = _crockfordIndex(ch);
    if (v < 0) {
      throw PairingPayloadDecodeException(
        PairingPayloadDecodeError.badAlphabet,
        'character ${ch.toUpperCase()} at index $i is not Crockford Base32',
      );
    }
    buffer = (buffer << 5) | v;
    bits += 5;
    if (bits >= 8) {
      bits -= 8;
      bytes.add((buffer >> bits) & 0xff);
    }
  }
  // Trailing bits < 8 are the encode-time padding bits (zeros) and
  // are intentionally discarded — they carry no data.
  return Uint8List.fromList(bytes);
}

int _crockfordIndex(String ch) {
  // Loose decode per Crockford's "decoding ambiguous characters"
  // table: I/L → 1, O → 0, U → V (Crockford intentionally excludes
  // U for obscenity prevention but most conventions decode it as V).
  switch (ch.toUpperCase()) {
    case 'I':
    case 'L':
      return _crockfordAlphabet.indexOf('1');
    case 'O':
      return _crockfordAlphabet.indexOf('0');
    case 'U':
      return _crockfordAlphabet.indexOf('V');
  }
  final idx = _crockfordAlphabet.indexOf(ch.toUpperCase());
  return idx;
}

String _groupFour(String raw) {
  if (raw.isEmpty) return raw;
  final sb = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    if (i > 0 && i % 4 == 0) sb.write('-');
    sb.write(raw[i]);
  }
  return sb.toString();
}

String _normalizeManualCode(String input) {
  final sb = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final ch = input[i];
    // Strip all whitespace and grouping hyphens; keep alphanumerics
    // for downstream decode validation.
    if (ch == '-' || ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r') {
      continue;
    }
    sb.write(ch);
  }
  return sb.toString().toUpperCase();
}
