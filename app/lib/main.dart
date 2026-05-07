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
import 'package:magicshare_app/provider/local_ip_provider.dart';
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
            switch (state) {
              case AppLifecycleState.resumed:
              case AppLifecycleState.inactive:
                ref.redux(localIpProvider).dispatch(InitLocalIpAction());
                ref.notifier(linuxWakePollerProvider).start();
                // Background FCM isolate may have persisted wake nonces
                // while we were paused; drain them into the in-memory
                // registry so an incoming prepareUpload auto-accepts.
                // ignore: discarded_futures
                ref.notifier(cloudMessageListenerProvider).drainPersistence();
                break;
              case AppLifecycleState.paused:
              case AppLifecycleState.hidden:
                if (!checkPlatformIsDesktop()) {
                  ref.notifier(linuxWakePollerProvider).stop();
                }
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
