import 'package:common/isolate.dart';
import 'package:magicshare_app/provider/favorites_provider.dart';
import 'package:magicshare_app/provider/logging/discovery_logs_provider.dart';
import 'package:magicshare_app/provider/persistence_provider.dart';
import 'package:magicshare_app/rust/api/webrtc.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';

@GenerateNiceMocks([
  MockSpec<PersistenceService>(),
  MockSpec<SharedPreferences>(),
  MockSpec<IsolateController>(),
  MockSpec<FavoritesService>(),
  MockSpec<DiscoveryLogger>(),
  MockSpec<LsSignalingConnection>(),
])
void main() {}
