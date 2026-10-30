import 'package:flutter/material.dart';
import 'package:material_ui/material_ui.dart' as material_ui;
import 'package:provider/provider.dart';

import 'core/notifications/push_notifications.dart';
import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/connection_provider.dart';
import 'providers/feed_provider.dart';
import 'providers/player_provider.dart';
import 'providers/post_provider.dart';
import 'providers/squad_provider.dart';
import 'providers/tournament_provider.dart';
import 'screens/start_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PushNotifications.instance.init();
  runApp(const GamifyApp());
}

class GamifyApp extends StatelessWidget {
  const GamifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
        ChangeNotifierProvider(create: (_) => ConnectionProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => SquadProvider()),
        ChangeNotifierProvider(create: (_) => TournamentProvider()),
        ChangeNotifierProvider(create: (_) => PostProvider()),
        ChangeNotifierProvider(create: (_) => FeedProvider()),
      ],
      child: MaterialApp(
        title: 'GAMIFY',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        // The post image editor is built on material_ui and needs its localizations
        localizationsDelegates: material_ui.GlobalMaterialLocalizations.delegates,
        // Lets a tapped notification open the right screen
        navigatorKey: PushNotifications.navigatorKey,
        home: const StartScreen(),
      ),
    );
  }
}
