import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/util/native/secure_storage_service.dart';

class _InMemoryStorage {
  final Map<String, String> _store = <String, String>{};
  int reads = 0;
  int writes = 0;
  int deletes = 0;

  SecureStorageGateway gateway() => SecureStorageGateway(
    read: (key) async {
      reads++;
      return _store[key];
    },
    write: (key, value) async {
      writes++;
      _store[key] = value;
    },
    delete: (key) async {
      deletes++;
      _store.remove(key);
    },
  );
}

void main() {
  group('SecureStorageService', () {
    test('round-trips a value through read/write/delete', () async {
      final fake = _InMemoryStorage();
      final service = SecureStorageService(gateway: fake.gateway());

      expect(await service.read(cloudDeviceIdKey), isNull);
      await service.write(cloudDeviceIdKey, 'abc-123');
      expect(await service.read(cloudDeviceIdKey), 'abc-123');
      await service.delete(cloudDeviceIdKey);
      expect(await service.read(cloudDeviceIdKey), isNull);

      expect(fake.reads, 3);
      expect(fake.writes, 1);
      expect(fake.deletes, 1);
    });

    test('keys are independent', () async {
      final fake = _InMemoryStorage();
      final service = SecureStorageService(gateway: fake.gateway());

      await service.write(cloudDeviceIdKey, 'device');
      await service.write(cloudGroupKeyKey, 'key');
      await service.delete(cloudDeviceIdKey);

      expect(await service.read(cloudDeviceIdKey), isNull);
      expect(await service.read(cloudGroupKeyKey), 'key');
    });

    test('overwrites an existing value', () async {
      final fake = _InMemoryStorage();
      final service = SecureStorageService(gateway: fake.gateway());

      await service.write(cloudGroupKeyKey, 'first');
      await service.write(cloudGroupKeyKey, 'second');

      expect(await service.read(cloudGroupKeyKey), 'second');
    });
  });
}
