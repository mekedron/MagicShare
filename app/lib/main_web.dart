// Entry point for the Flutter web build of MagicShare.
//
// The native [main] in `main.dart` pulls in tray, window manager, bitsdojo,
// win32, share_handler, rhttp, and flutter_rust_bridge — none of which compile
// to JS. This file imports only the cross-platform surface so
// `flutter build web -t lib/main_web.dart` succeeds.
//
// We start with a placeholder home page. Cloud sync (Epics 6+) lands here
// first; native builds adopt the unified path once the rust-bridge code paths
// are gated.

import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MagicShareWebApp());
}

class MagicShareWebApp extends StatelessWidget {
  const MagicShareWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MagicShare',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: const _WebPlaceholderPage(),
    );
  }
}

class _WebPlaceholderPage extends StatelessWidget {
  const _WebPlaceholderPage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('MagicShare')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_outlined, size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text(
                  'MagicShare web is under construction.',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Cloud-assisted device sync ships incrementally — see '
                  'docs/development/task-list.md for the epic checklist.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
