import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ads/ad_service.dart';
import 'audio/sfx.dart';
import 'save/progress.dart';
import 'ui/menu_screen.dart';
import 'ui/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light));
  runApp(const WrongChatApp());
}

class WrongChatApp extends StatefulWidget {
  const WrongChatApp({super.key});
  @override
  State<WrongChatApp> createState() => _WrongChatAppState();
}

class _WrongChatAppState extends State<WrongChatApp> {
  late final Future<void> _boot = _init();

  Future<void> _init() async {
    final progress = await Progress.load();
    progress.bumpSession();
    App.progress = progress;
    Sfx.muted = progress.muted;
    Sfx.haptics = progress.haptics;
    App.ads = AdService.create(sessions: progress.sessions, nav: App.nav);
    unawaited(Sfx.init().then((_) => Music.init(enabled: !progress.muted)));
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Wrong Chat',
    debugShowCheckedModeBanner: false,
    navigatorKey: App.nav,
    theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Fredoka', useMaterial3: true),
    home: FutureBuilder<void>(
      future: _boot,
      builder: (_, snap) {
        if (snap.hasError) {
          return Backdrop(
            child: Center(child: Text('Could not start: ${snap.error}', style: uiStyle(16))),
          );
        }
        if (snap.connectionState != ConnectionState.done) {
          return ColoredBox(
            color: Pal.night,
            child: Center(child: Text('💬', style: displayStyle(64))),
          );
        }
        return const MenuScreen();
      },
    ),
  );
}
