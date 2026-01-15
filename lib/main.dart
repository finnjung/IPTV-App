import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'theme/app_theme.dart';
import 'shared/widgets/main_navigation.dart';
import 'services/xtream_service.dart';
import 'services/navigation_sound_service.dart';
import 'utils/tv_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize MediaKit for video playback
  MediaKit.ensureInitialized();

  // Initialize TV detection for Android TV / Fire TV
  await TvUtils.initialize();

  // Initialize navigation sounds
  await NavigationSoundService().initialize();

  // Initialize window_manager for desktop platforms
  if (!kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    await windowManager.ensureInitialized();
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.surfaceDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const IPTVApp());
}

class IPTVApp extends StatelessWidget {
  const IPTVApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => XtreamService()..loadSavedCredentials(),
        ),
      ],
      child: MaterialApp(
        title: 'IPTV Player',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const MainNavigation(),
      ),
    );
  }
}
