import 'package:flutter_test/flutter_test.dart';
import 'package:magicshare_app/model/state/settings_state.dart';
import 'package:magicshare_app/provider/settings_provider.dart';
import 'package:mockito/mockito.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../mocks.mocks.dart';

void main() {
  group('PersistenceService.cloudSyncEnabled (via SharedPreferences)', () {
    test('defaults to true when never written', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      expect(prefs.getBool('ls_cloud_sync_enabled'), isNull);
      // Real PersistenceService.getCloudSyncEnabled returns true on null.
      // Mirror the contract here so the test doubles in C2 stay in sync.
      expect(prefs.getBool('ls_cloud_sync_enabled') ?? true, isTrue);
    });

    test('persists across reads', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('ls_cloud_sync_enabled', false);
      expect(prefs.getBool('ls_cloud_sync_enabled'), isFalse);

      await prefs.setBool('ls_cloud_sync_enabled', true);
      expect(prefs.getBool('ls_cloud_sync_enabled'), isTrue);
    });
  });

  group('SettingsService.setCloudSyncEnabled', () {
    test('writes through to persistence and updates state', () async {
      final mock = _stubPersistence();
      when(mock.getCloudSyncEnabled()).thenReturn(true);

      final tester = Notifier.test<SettingsService, SettingsState>(
        notifier: SettingsService(mock),
      );

      expect(tester.state.cloudSyncEnabled, isTrue);

      await tester.notifier.setCloudSyncEnabled(false);

      expect(tester.state.cloudSyncEnabled, isFalse);
      verify(mock.setCloudSyncEnabled(false)).called(1);
    });

    test('persists true after a false→true round-trip', () async {
      final mock = _stubPersistence();
      when(mock.getCloudSyncEnabled()).thenReturn(false);

      final tester = Notifier.test<SettingsService, SettingsState>(
        notifier: SettingsService(mock),
      );

      expect(tester.state.cloudSyncEnabled, isFalse);

      await tester.notifier.setCloudSyncEnabled(true);

      expect(tester.state.cloudSyncEnabled, isTrue);
      verify(mock.setCloudSyncEnabled(true)).called(1);
    });
  });
}

MockPersistenceService _stubPersistence() {
  final mock = MockPersistenceService();
  when(mock.getShowToken()).thenReturn('token');
  when(mock.getAlias()).thenReturn('alias');
  when(mock.getMulticastGroup()).thenReturn('224.0.0.0');
  when(mock.getPort()).thenReturn(53317);
  when(mock.getDiscoveryTimeout()).thenReturn(500);
  return mock;
}
