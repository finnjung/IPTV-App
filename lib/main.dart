import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'theme/app_theme.dart';
import 'shared/widgets/main_navigation.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/loading_screen.dart';
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
        home: const _AppWithSplash(),
      ),
    );
  }
}

/// App-Zustand nach Splash Screen
enum _AppState {
  splash,           // Splash Screen wird angezeigt
  onboarding,       // Onboarding wird angezeigt
  loading,          // LoadingScreen für langsames Laden (API)
  ready,            // MainNavigation wird angezeigt
}

class _AppWithSplash extends StatefulWidget {
  const _AppWithSplash();

  @override
  State<_AppWithSplash> createState() => _AppWithSplashState();
}

class _AppWithSplashState extends State<_AppWithSplash> {
  _AppState _state = _AppState.splash;

  void _handleSplashComplete(SplashResult result) {
    setState(() {
      switch (result) {
        case SplashResult.needsOnboarding:
          _state = _AppState.onboarding;
          break;
        case SplashResult.readyWithLoading:
          _state = _AppState.loading;
          break;
        case SplashResult.ready:
          _state = _AppState.ready;
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_state) {
      case _AppState.splash:
        return SplashScreen(
          onComplete: _handleSplashComplete,
        );

      case _AppState.onboarding:
        return OnboardingScreen(
          onComplete: () {
            // Nach Onboarding zeigen wir den LoadingScreen (erstes Laden ist immer langsam)
            setState(() => _state = _AppState.loading);
          },
        );

      case _AppState.loading:
        return LoadingScreen(
          onComplete: () => setState(() => _state = _AppState.ready),
        );

      case _AppState.ready:
        return const MainNavigation();
    }
  }
}
