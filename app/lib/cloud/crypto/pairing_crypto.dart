import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/api.dart' show KeyParameter, ParametersWithRandom, SecureRandom;
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/ecc/api.dart' show ECDomainParameters, ECPrivateKey, ECPublicKey;
import 'package:pointycastle/ecc/ecdh.dart' show ECDHBasicAgreement;
import 'package:pointycastle/key_derivators/api.dart' show HkdfParameters;
import 'package:pointycastle/key_derivators/hkdf.dart' show HKDFKeyDerivator;
import 'package:pointycastle/key_generators/api.dart' show ECKeyGeneratorParameters;
import 'package:pointycastle/key_generators/ec_key_generator.dart' show ECKeyGenerator;
import 'package:pointycastle/random/fortuna_random.dart' show FortunaRandom;

/// Pairing-side cryptography for the Epic 11 LAN key handshake.
///
/// The issuing device and the joining device each generate an
/// ephemeral P-256 (secp256r1 / NIST P-256 / prime256v1 — three names
/// for the same curve) keypair and exchange compressed public keys
/// over the QR / manual-code payload. ECDH yields a 32-byte shared
/// secret which both sides feed into HKDF-SHA256 to derive a 32-byte
/// AES-256 key, which then encrypts the actual group shared key as
/// it traverses the LAN endpoint.
///
/// Why P-256 and not X25519: pointycastle (already a transitive dep
/// via the LocalSend TLS path) ships full P-256 support but no
/// Curve25519 / X25519 primitives. Pulling in `cryptography` just
/// for X25519 is unnecessary churn, and P-256's public-key encoding
/// (33 bytes compressed) fits comfortably in the QR / manual-code
/// payload. The threat model — an attacker who saw the QR plus an
/// eavesdropper on the LAN — is satisfied by either curve.

const _curveName = 'secp256r1';

/// Curve field size in bytes — used for fixed-width encoding of
/// shared-secret BigInts and for sanity-checking compressed public
/// keys.
const int p256FieldSizeBytes = 32;

/// SEC1 compressed-point length: a 1-byte parity prefix plus the
/// 32-byte X coordinate.
const int p256CompressedPubkeyBytes = 33;

/// HKDF salt for the pairing key derivation. Versioned so the
/// protocol can rotate without colliding with prior derivations.
final Uint8List _pairingHkdfSalt = Uint8List.fromList(
  'magicshare-pair/v1'.codeUnits,
);

/// HKDF info for the pairing key derivation. Distinct per
/// purpose-of-derivation so future uses of the same shared secret
/// can derive non-colliding keys.
final Uint8List _pairingHkdfInfo = Uint8List.fromList(
  'magicshare-pair-key'.codeUnits,
);

/// AES-256 key length in bytes. The pairing AEAD key reuses the
/// existing group-key AES-256-GCM helper, which expects a 32-byte
/// key.
const int pairingAesKeyLengthBytes = 32;

/// Bundle of an ephemeral P-256 keypair held by either side of the
/// pairing handshake. The private half stays on the device; the
/// compressed public half travels over the QR / manual code.
class PairingKeyPair {
  PairingKeyPair({required this.privateKey, required this.publicKey});

  final ECPrivateKey privateKey;
  final ECPublicKey publicKey;
}

/// Generates a fresh ephemeral P-256 keypair seeded from
/// `Random.secure()`. Each call returns a new keypair — never reuse.
PairingKeyPair generatePairingKeyPair() {
  final domainParams = ECDomainParameters(_curveName);
  final secureRandom = _newSecureRandom();
  final keyParams = ECKeyGeneratorParameters(domainParams);
  final generator = ECKeyGenerator()..init(ParametersWithRandom(keyParams, secureRandom));
  final pair = generator.generateKeyPair();
  return PairingKeyPair(
    privateKey: pair.privateKey as ECPrivateKey,
    publicKey: pair.publicKey as ECPublicKey,
  );
}

/// Encodes [pub] as a 33-byte SEC1 compressed point. Throws
/// [ArgumentError] if the point cannot be encoded (e.g. it's the
/// point at infinity, which is never a valid public key here).
Uint8List compressPublicKey(ECPublicKey pub) {
  final point = pub.Q;
  if (point == null || point.isInfinity) {
    throw ArgumentError('Cannot compress point at infinity');
  }
  final encoded = point.getEncoded(true);
  if (encoded.length != p256CompressedPubkeyBytes) {
    throw StateError(
      'Expected $p256CompressedPubkeyBytes-byte compressed point, '
      'got ${encoded.length}',
    );
  }
  return Uint8List.fromList(encoded);
}

/// Decodes a SEC1 compressed P-256 point. Throws [ArgumentError] for
/// any malformed input (wrong length, wrong prefix byte, point not
/// on the curve).
ECPublicKey decompressPublicKey(Uint8List bytes) {
  if (bytes.length != p256CompressedPubkeyBytes) {
    throw ArgumentError(
      'Expected $p256CompressedPubkeyBytes-byte compressed point, '
      'got ${bytes.length}',
    );
  }
  final prefix = bytes[0];
  if (prefix != 0x02 && prefix != 0x03) {
    throw ArgumentError(
      'Bad SEC1 compressed prefix: 0x${prefix.toRadixString(16)} '
      '(expected 0x02 or 0x03)',
    );
  }
  final domainParams = ECDomainParameters(_curveName);
  final point = domainParams.curve.decodePoint(bytes);
  if (point == null || point.isInfinity) {
    throw ArgumentError('Decoded point is invalid (null or at infinity)');
  }
  return ECPublicKey(point, domainParams);
}

/// Performs a P-256 ECDH agreement between [privateKey] and
/// [peerPublicKey] and returns the shared secret as a
/// fixed-width 32-byte big-endian byte string. Both endpoints
/// computing this with the matched key halves arrive at the same
/// bytes.
Uint8List deriveSharedSecret(
  ECPrivateKey privateKey,
  ECPublicKey peerPublicKey,
) {
  final agreement = ECDHBasicAgreement()..init(privateKey);
  final z = agreement.calculateAgreement(peerPublicKey);
  return _bigIntToFixedBytes(z, p256FieldSizeBytes);
}

/// HKDF-SHA256 (RFC 5869). [length] is the number of output bytes;
/// must be in `[1, 255 * 32]`. [salt] and [info] may be empty.
Uint8List hkdfSha256({
  required Uint8List ikm,
  required Uint8List salt,
  required Uint8List info,
  required int length,
}) {
  if (length < 1 || length > 255 * 32) {
    throw ArgumentError('HKDF length out of range: $length');
  }
  final hkdf = HKDFKeyDerivator(SHA256Digest());
  hkdf.init(HkdfParameters(ikm, length, salt, info));
  final out = Uint8List(length);
  hkdf.deriveKey(null, 0, out, 0);
  return out;
}

/// Derives the 32-byte AES-256 key used to wrap the group shared key
/// during the LAN handshake. Uses fixed pairing-versioned salt and
/// info strings so independent calls with the same shared secret
/// yield the same key.
Uint8List derivePairingAesKey(Uint8List sharedSecret) {
  return hkdfSha256(
    ikm: sharedSecret,
    salt: _pairingHkdfSalt,
    info: _pairingHkdfInfo,
    length: pairingAesKeyLengthBytes,
  );
}

// ---------------------------------------------------------------------------
// Internals
// ---------------------------------------------------------------------------

/// Seeds Fortuna with 32 bytes from `Random.secure()`. The OS RNG is
/// the actual entropy source; Fortuna just gives pointycastle a
/// SecureRandom with the API shape its key generators want.
SecureRandom _newSecureRandom() {
  final rnd = Random.secure();
  final seed = Uint8List(32);
  for (var i = 0; i < seed.length; i++) {
    seed[i] = rnd.nextInt(256);
  }
  return FortunaRandom()..seed(KeyParameter(seed));
}

/// Big-endian 2's-complement-free encoding of a non-negative
/// [BigInt] as a fixed [width]-byte block. Truncation throws if the
/// value doesn't fit; smaller values are zero-prefixed on the left.
/// Required because ECDH agreements yield BigInts of variable
/// effective length (the leading byte can be zero), but downstream
/// consumers (HKDF, AES key import) expect fixed-width input.
Uint8List _bigIntToFixedBytes(BigInt value, int width) {
  if (value.isNegative) {
    throw ArgumentError('BigInt must be non-negative');
  }
  final out = Uint8List(width);
  var v = value;
  for (var i = width - 1; i >= 0; i--) {
    out[i] = (v & BigInt.from(0xff)).toInt();
    v = v >> 8;
  }
  if (v != BigInt.zero) {
    throw ArgumentError('BigInt too large for $width bytes');
  }
  return out;
}
