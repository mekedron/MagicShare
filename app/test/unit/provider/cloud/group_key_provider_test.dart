import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/cloud/crypto/group_key_codec.dart';
import 'package:magicshare_app/provider/cloud/group_key_provider.dart';
import 'package:magicshare_app/util/native/secure_storage_service.dart';
import 'package:refena_flutter/refena_flutter.dart';

class _InMemoryStorage {
  final Map<String, String> _store = <String, String>{};

  SecureStorageService service() => SecureStorageService(
    gateway: SecureStorageGateway(
      read: (key) async => _store[key],
      write: (key, value) async => _store[key] = value,
      delete: (key) async => _store.remove(key),
    ),
  );

  String? get(String key) => _store[key];
  void put(String key, String value) => _store[key] = value;
}

void main() {
  group('GroupKeyService.init', () {
    test('starts in Loading and resolves to Missing when storage is empty', () async {
      final storage = _InMemoryStorage();
      final tester = Notifier.test<GroupKeyService, GroupKeyState>(
        notifier: GroupKeyService(storage: storage.service()),
      );

      expect(tester.state, isA<GroupKeyLoading>());
      await pumpEventQueue();
      expect(tester.state, isA<GroupKeyMissing>());
    });

    test('resolves to Ready when a base64 key is already in storage', () async {
      final original = Uint8List.fromList(List.generate(32, (i) => i + 1));
      final storage = _InMemoryStorage()..put(cloudGroupKeyKey, base64Encode(original));
      final tester = Notifier.test<GroupKeyService, GroupKeyState>(
        notifier: GroupKeyService(storage: storage.service()),
      );

      await pumpEventQueue();
      final state = tester.state;
      expect(state, isA<GroupKeyReady>());
      expect((state as GroupKeyReady).key, original);
    });

    test('surfaces a corrupt stored key as GroupKeyFailed', () async {
      final storage = _InMemoryStorage()..put(cloudGroupKeyKey, base64Encode(Uint8List(16)));
      final tester = Notifier.test<GroupKeyService, GroupKeyState>(
        notifier: GroupKeyService(storage: storage.service()),
      );

      await pumpEventQueue();
      expect(tester.state, isA<GroupKeyFailed>());
    });
  });

  group('GroupKeyService.ensureForNewAccount', () {
    test('generates a key, persists it, and transitions to Ready', () async {
      final storage = _InMemoryStorage();
      final fixed = Uint8List.fromList(List.generate(32, (i) => 0xab));
      final tester = Notifier.test<GroupKeyService, GroupKeyState>(
        notifier: GroupKeyService(
          storage: storage.service(),
          keyGenerator: () => fixed,
        ),
      );
      await pumpEventQueue();
      expect(tester.state, isA<GroupKeyMissing>());

      final returned = await tester.notifier.ensureForNewAccount();

      expect(returned, fixed);
      expect(tester.state, isA<GroupKeyReady>());
      expect((tester.state as GroupKeyReady).key, fixed);
      expect(storage.get(cloudGroupKeyKey), base64Encode(fixed));
    });

    test('is idempotent — second call returns the same key without rotating', () async {
      final storage = _InMemoryStorage();
      var calls = 0;
      final tester = Notifier.test<GroupKeyService, GroupKeyState>(
        notifier: GroupKeyService(
          storage: storage.service(),
          keyGenerator: () {
            calls++;
            return Uint8List.fromList(List.generate(32, (_) => calls));
          },
        ),
      );
      await pumpEventQueue();

      final first = await tester.notifier.ensureForNewAccount();
      final second = await tester.notifier.ensureForNewAccount();

      expect(second, first);
      expect(calls, 1);
    });
  });

  group('GroupKeyService.replace', () {
    test('writes the supplied key to storage and updates state', () async {
      final storage = _InMemoryStorage();
      final tester = Notifier.test<GroupKeyService, GroupKeyState>(
        notifier: GroupKeyService(storage: storage.service()),
      );
      await pumpEventQueue();

      final pairedKey = Uint8List.fromList(List.generate(32, (i) => 0x77));
      await tester.notifier.replace(pairedKey);

      expect((tester.state as GroupKeyReady).key, pairedKey);
      expect(storage.get(cloudGroupKeyKey), base64Encode(pairedKey));
    });

    test('rejects a key of the wrong length', () async {
      final tester = Notifier.test<GroupKeyService, GroupKeyState>(
        notifier: GroupKeyService(storage: _InMemoryStorage().service()),
      );
      await pumpEventQueue();

      expect(
        () => tester.notifier.replace(Uint8List(16)),
        throwsArgumentError,
      );
    });
  });

  group('GroupKeyService.clear', () {
    test('wipes both the group key and the device id in storage', () async {
      final storage = _InMemoryStorage()
        ..put(cloudGroupKeyKey, base64Encode(generateGroupKey()))
        ..put(cloudDeviceIdKey, 'existing-device-id');
      final tester = Notifier.test<GroupKeyService, GroupKeyState>(
        notifier: GroupKeyService(storage: storage.service()),
      );
      await pumpEventQueue();
      expect(tester.state, isA<GroupKeyReady>());

      await tester.notifier.clear();

      expect(tester.state, isA<GroupKeyMissing>());
      expect(storage.get(cloudGroupKeyKey), isNull);
      expect(storage.get(cloudDeviceIdKey), isNull);
    });
  });
}
