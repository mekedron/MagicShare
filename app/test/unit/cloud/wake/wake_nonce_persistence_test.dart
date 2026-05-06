import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/cloud/wake/wake_nonce_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('WakeNoncePersistence', () {
    test('append + drain round-trips the entry', () async {
      const persistence = WakeNoncePersistence();
      final expiresAt = DateTime.now().add(const Duration(minutes: 2));
      await persistence.append('nonce-a', expiresAt);

      final drained = await persistence.drain();
      expect(drained, hasLength(1));
      expect(drained.first.nonce, 'nonce-a');
      expect(
        drained.first.expiresAt.millisecondsSinceEpoch,
        expiresAt.millisecondsSinceEpoch,
      );
    });

    test('drain clears the slot', () async {
      const persistence = WakeNoncePersistence();
      await persistence.append('nonce-a', DateTime.now().add(const Duration(minutes: 2)));

      await persistence.drain();
      final second = await persistence.drain();
      expect(second, isEmpty);
    });

    test('multiple appends accumulate', () async {
      const persistence = WakeNoncePersistence();
      final expiresAt = DateTime.now().add(const Duration(minutes: 2));
      await persistence.append('nonce-a', expiresAt);
      await persistence.append('nonce-b', expiresAt);

      final drained = await persistence.drain();
      expect(drained.map((e) => e.nonce), containsAll(<String>['nonce-a', 'nonce-b']));
    });

    test('drain drops entries whose expiry has already passed', () async {
      const persistence = WakeNoncePersistence();
      // Bypass the append-time filter by writing directly with an
      // already-expired timestamp via a manual append sequence: append a
      // long-lived entry, then mutate the underlying slot to simulate a
      // stale read. We do that by writing a raw stale entry first.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        wakeNoncePersistenceKey,
        '[{"nonce":"stale","expiresAtMs":1}]',
      );

      final drained = await persistence.drain();
      expect(drained, isEmpty);
    });

    test('append drops entries already past expiry instead of writing them', () async {
      const persistence = WakeNoncePersistence();
      await persistence.append(
        'already-expired',
        DateTime.now().subtract(const Duration(seconds: 1)),
      );

      final prefs = await SharedPreferences.getInstance();
      // Either no slot was created or the slot is an empty list — both fine.
      final raw = prefs.getString(wakeNoncePersistenceKey) ?? '[]';
      expect(raw == '[]' || raw == '', isTrue, reason: 'raw was: $raw');
    });

    test('drain tolerates corrupt JSON by clearing the slot', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(wakeNoncePersistenceKey, 'not-json{');

      const persistence = WakeNoncePersistence();
      final drained = await persistence.drain();
      expect(drained, isEmpty);
    });

    test('drain skips malformed entries instead of throwing', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        wakeNoncePersistenceKey,
        '[{"nonce":42,"expiresAtMs":1234567890},{"nonce":"good","expiresAtMs":99999999999999}]',
      );

      const persistence = WakeNoncePersistence();
      final drained = await persistence.drain();
      expect(drained, hasLength(1));
      expect(drained.first.nonce, 'good');
    });

    test('append filters expired entries out of the existing buffer', () async {
      final prefs = await SharedPreferences.getInstance();
      // Seed a stale entry directly.
      await prefs.setString(
        wakeNoncePersistenceKey,
        '[{"nonce":"stale","expiresAtMs":1}]',
      );

      const persistence = WakeNoncePersistence();
      await persistence.append(
        'fresh',
        DateTime.now().add(const Duration(minutes: 2)),
      );

      final drained = await persistence.drain();
      expect(drained, hasLength(1));
      expect(drained.first.nonce, 'fresh');
    });
  });
}
