import 'package:logging/logging.dart';
import 'package:magicshare_app/provider/local_ip_provider.dart';
import 'package:magicshare_app/provider/logging/discovery_logs_provider.dart';
import 'package:magicshare_app/provider/progress_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:refena_inspector_client/refena_inspector_client.dart';

final _logger = Logger('Refena');

class CustomRefenaObserver extends RefenaMultiObserver {
  CustomRefenaObserver()
    : super(
        observers: [
          RefenaDebugObserver(
            onLine: (line) => _logger.info(line),
            exclude: _exclude,
          ),
          RefenaTracingObserver(
            limit: 100,
            exclude: _exclude,
          ),
          RefenaInspectorObserver(),
        ],
      );
}

/// Names of actions whose dispatch/finish events fire on every nearby-
/// devices poller tick (≈ every 2 s) and add no signal to the console.
/// Match by stringified runtime type so leading underscores on private
/// classes still hit.
const Set<String> _noisyPollActions = {
  '_FetchLocalIpAction',
  'StartNearbyDevicesPoller',
  'StartMulticastScan',
  'IsolateSendMulticastAnnouncementAction',
  'ProbeAndPruneKnownDevicesAction',
  'IsolateFavoriteHttpDiscoveryAction',
  'RegisterDeviceAction',
};

bool _exclude(RefenaEvent event) {
  return switch (event) {
    ChangeEvent() => event.notifier is DiscoveryLogger || event.notifier is LocalIpService || event.notifier is ProgressNotifier,
    ActionDispatchedEvent() => _noisyPollActions.contains(event.action.runtimeType.toString()),
    ActionFinishedEvent() => _noisyPollActions.contains(event.action.runtimeType.toString()),
    _ => false,
  };
}
