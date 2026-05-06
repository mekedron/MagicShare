import 'package:flutter/material.dart';

class LifeCycleWatcher extends StatefulWidget {
  final Widget child;
  final void Function(AppLifecycleState state) onChangedState;

  const LifeCycleWatcher({required this.child, required this.onChangedState, super.key});

  @override
  State<LifeCycleWatcher> createState() => _LifeCycleWatcherState();
}

class _LifeCycleWatcherState extends State<LifeCycleWatcher> with WidgetsBindingObserver {
  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Flutter's `didChangeAppLifecycleState` only fires on *transitions*
    // — it never reports the initial state at app launch. That bit us:
    // on Android, `presenceHeartbeatProvider.markForeground()` lives
    // inside `onChangedState(resumed)`, so a fresh launch (which is
    // already in `resumed`) never ran the call and the cloud
    // heartbeat sat in `HeartbeatIdle` until the next lifecycle
    // transition (could be 10+ minutes if the user just leaves the
    // app open). The user-visible symptom: macOS sees Android's
    // cloud `lastSeenAtMs` frozen → `cloudDeviceIsOnline` returns
    // false → green-dot conjunction false → "Android offline".
    //
    // Fire the current lifecycle state once after the first frame so
    // the foreground-side providers (heartbeat, LAN liveness, wake
    // poller) bootstrap correctly. Doing it post-frame avoids
    // dispatching state mutations during `initState`'s build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final initial = WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
      widget.onChangedState(initial);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.onChangedState(state);
  }
}
