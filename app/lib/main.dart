import 'package:common/isolate.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:magicshare_app/cloud/wake/cloud_background_handler.dart';
import 'package:magicshare_app/config/init.dart';
import 'package:magicshare_app/config/init_error.dart';
import 'package:magicshare_app/config/theme.dart';
import 'package:magicshare_app/gen/strings.g.dart';
import 'package:magicshare_app/model/persistence/color_mode.dart';
import 'package:magicshare_app/pages/home_page.dart';
import 'package:magicshare_app/provider/cloud/cloud_message_listener_provider.dart';
import 'package:magicshare_app/provider/cloud/linux_wake_poller_provider.dart';
import 'package:magicshare_app/provider/cloud/presence_heartbeat_service.dart';
import 'package:magicshare_app/provider/local_ip_provider.dart';
import 'package:magicshare_app/provider/network/lan_liveness_service.dart';
import 'package:magicshare_app/provider/settings_provider.dart';
import 'package:magicshare_app/util/native/cloud_platform.dart';
import 'package:magicshare_app/util/native/platform_check.dart';
import 'package:magicshare_app/util/ui/dynamic_colors.dart';
import 'package:magicshare_app/widget/watcher/life_cycle_watcher.dart';
import 'package:magicshare_app/widget/watcher/shortcut_watcher.dart';
import 'package:magicshare_app/widget/watcher/tray_watcher.dart';
import 'package:magicshare_app/widget/watcher/window_watcher.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

Future<void> main(List<String> args) async {
  final RefenaContainer container;
  try {
    container = await preInit(args);
  } catch (e, stackTrace) {
    showInitErrorApp(
      error: e,
      stackTrace: stackTrace,
    );
    return;
  }

  // Register the background FCM handler before runApp. The handler runs
  // in its own isolate when the OS delivers a wake / link data message
  // while the main isolate is paused or terminated; it persists wake
  // nonces and lets the main isolate pick them up on next foreground.
  if (checkPlatformSupportsFcm()) {
    FirebaseMessaging.onBackgroundMessage(cloudBackgroundMessageHandler);
  }

  runApp(
    RefenaScope.withContainer(
      container: container,
      child: TranslationProvider(
        child: const MagicShareApp(),
      ),
    ),
  );
}

class MagicShareApp extends StatelessWidget {
  const MagicShareApp();

  @override
  Widget build(BuildContext context) {
    final ref = context.ref;
    final (themeMode, colorMode) = ref.watch(settingsProvider.select((settings) => (settings.theme, settings.colorMode)));
    final dynamicColors = ref.watch(dynamicColorsProvider);
    return TrayWatcher(
      child: WindowWatcher(
        child: LifeCycleWatcher(
          onChangedState: (AppLifecycleState state) {
            // Desktop and mobile read AppLifecycleState differently:
            // - macOS / Windows / Linux: `inactive` and `hidden` fire
            //   when another window steals focus or the user minimises.
            //   The MagicShare process is still alive and reachable, so
            //   it should stay online.
            // - Android / iOS: only `paused` / `hidden` mean the OS
            //   actually suspended the app — it can't respond to LAN
            //   sends until FCM wakes it. Mark offline there so peers
            //   fall back to the wake-then-send path.
            //
            // `inactive` is treated as foreground on both platforms.
            // On the Android emulator running inside a macOS window
            // (and on iOS during transient system events like a phone
            // call banner) the Activity often sits at `inactive` while
            // still being fully visible to the user. Treating it as
            // background made the emulator look permanently offline
            // from every other device, which the user reported.
            // Treating it as background AND treating it as foreground
            // (as we did before this fix) caused the device to flap
            // online / offline as the host window's focus oscillated.
            // The middle ground — `inactive` keeps presence online —
            // matches the expectation that "if the app is on screen
            // and the process is alive, peers should see it as
            // online".
            final isDesktop = checkPlatformIsDesktop();
            switch (state) {
              case AppLifecycleState.resumed:
              case AppLifecycleState.inactive:
                ref.redux(localIpProvider).dispatch(InitLocalIpAction());
                ref.notifier(presenceHeartbeatProvider).markForeground();
                ref.notifier(lanLivenessProvider).markForeground();
                ref.notifier(linuxWakePollerProvider).start();
                // Background FCM isolate may have persisted wake nonces
                // while we were paused; drain them into the in-memory
                // registry so an incoming prepareUpload auto-accepts.
                // ignore: discarded_futures
                ref.notifier(cloudMessageListenerProvider).drainPersistence();
                break;
              case AppLifecycleState.paused:
              case AppLifecycleState.hidden:
                if (!isDesktop) {
                  ref.notifier(presenceHeartbeatProvider).markBackground();
                  ref.notifier(lanLivenessProvider).markBackground();
                  ref.notifier(linuxWakePollerProvider).stop();
                }
                // Desktop: window minimised, hidden, or moved to
                // another Space — the process is still alive and the
                // LAN listener still works. Stay online so peers
                // don't see us flap to offline every time the user
                // switches windows. The heartbeat and the LAN
                // re-announce loop continue; they only stop on
                // `detached`.
                break;
              case AppLifecycleState.detached:
                // The main isolate is only exited when all child isolates are exited.
                // https://github.com/localsend/localsend/issues/1568
                ref.redux(parentIsolateProvider).dispatch(IsolateDisposeAction());
                break;
            }
          },
          child: ShortcutWatcher(
            child: MaterialApp(
              title: t.appName,
              locale: TranslationProvider.of(context).flutterLocale,
              supportedLocales: AppLocaleUtils.supportedLocales,
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              debugShowCheckedModeBanner: false,
              theme: getTheme(colorMode, Brightness.light, dynamicColors),
              darkTheme: getTheme(colorMode, Brightness.dark, dynamicColors),
              themeMode: colorMode == ColorMode.oled ? ThemeMode.dark : themeMode,
              navigatorKey: Routerino.navigatorKey,
              home: RouterinoHome(
                builder: () => const HomePage(
                  initialTab: HomeTab.receive,
                  appStart: true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
