import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/cloud/wake/wake_nonce_registry.dart';

void main() {
  group('WakeNonceRegistry', () {
    late DateTime now;
    late WakeNonceRegistry registry;

    setUp(() {
      now = DateTime.utc(2026, 5, 6, 12, 0, 0);
      registry = WakeNonceRegistry(clock: () => now);
    });

    test('register + consume returns true exactly once (single-use)', () {
      registry.register('nonce-a', now.add(const Duration(minutes: 2)));
      expect(registry.consume('nonce-a'), isTrue);
      expect(registry.consume('nonce-a'), isFalse);
    });

    test('consume returns false when nonce was never registered', () {
      expect(registry.consume('unknown'), isFalse);
    });

    test('consume returns false for expired nonces', () {
      registry.register('nonce-a', now.add(const Duration(minutes: 2)));
      now = now.add(const Duration(minutes: 3));
      expect(registry.consume('nonce-a'), isFalse);
    });

    test('register drops entries already past expiry', () {
      registry.register('expired', now.subtract(const Duration(seconds: 1)));
      expect(registry.consume('expired'), isFalse);
      expect(registry.size, 0);
    });

    test('register on an existing nonce extends the expiry', () {
      registry.register('nonce-a', now.add(const Duration(minutes: 1)));
      registry.register('nonce-a', now.add(const Duration(minutes: 5)));
      now = now.add(const Duration(minutes: 2));
      expect(registry.consume('nonce-a'), isTrue);
    });

    test('prune drops every entry whose expiry has passed', () {
      registry.register('keep', now.add(const Duration(minutes: 5)));
      registry.register('drop', now.add(const Duration(seconds: 1)));
      now = now.add(const Duration(seconds: 2));
      registry.prune();
      expect(registry.size, 1);
      expect(registry.consume('keep'), isTrue);
      expect(registry.consume('drop'), isFalse);
    });

    test('size reflects live entry count', () {
      expect(registry.size, 0);
      registry.register('a', now.add(const Duration(minutes: 1)));
      registry.register('b', now.add(const Duration(minutes: 1)));
      expect(registry.size, 2);
      registry.consume('a');
      expect(registry.size, 1);
    });

    test('boundary: an entry expiring at exactly `now` is no longer live', () {
      registry.register('edge', now.add(const Duration(minutes: 1)));
      now = now.add(const Duration(minutes: 1));
      expect(registry.consume('edge'), isFalse);
    });
  });
}
