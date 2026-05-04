import 'package:common/isolate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:magicshare_app/config/init.dart';
import 'package:magicshare_app/config/init_error.dart';
import 'package:magicshare_app/config/theme.dart';
import 'package:magicshare_app/gen/strings.g.dart';
import 'package:magicshare_app/model/persistence/color_mode.dart';
import 'package:magicshare_app/pages/home_page.dart';
import 'package:magicshare_app/provider/cloud/linux_wake_poller_provider.dart';
import 'package:magicshare_app/provider/cloud/presence_heartbeat_service.dart';
import 'package:magicshare_app/provider/local_ip_provider.dart';
import 'package:magicshare_app/provider/settings_provider.dart';
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
            //   it should stay "online" — flipping to offline on every
            //   focus change makes the device look offline to peers
            //   while the user is actively using the same machine.
            // - Android / iOS: `paused`/`hidden`/`inactive` mean the
            //   OS suspended the app. It can't respond to LAN sends
            //   until FCM wakes it. We mark offline so peers fall back
            //   to the wake-then-send path.
            final isDesktop = checkPlatformIsDesktop();
            switch (state) {
              case AppLifecycleState.resumed:
                ref.redux(localIpProvider).dispatch(InitLocalIpAction());
                ref.notifier(presenceHeartbeatProvider).markForeground();
                ref.notifier(linuxWakePollerProvider).start();
                break;
              case AppLifecycleState.paused:
              case AppLifecycleState.hidden:
                ref.notifier(presenceHeartbeatProvider).markBackground();
                ref.notifier(linuxWakePollerProvider).stop();
                break;
              case AppLifecycleState.inactive:
                if (!isDesktop) {
                  ref.notifier(presenceHeartbeatProvider).markBackground();
                  ref.notifier(linuxWakePollerProvider).stop();
                }
                // Desktop: another app stole focus, we're still here.
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
