import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:window_manager/window_manager.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'shared/widgets/main_navigation.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/loading_screen.dart';
import 'services/xtream_service.dart';
import 'services/navigation_sound_service.dart';
import 'services/app_update_service.dart';
import 'widgets/update_dialog.dart';
import 'utils/tv_utils.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (only on supported platforms)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase not configured for this platform (e.g., macOS) - continue without it
    debugPrint('Firebase not available on this platform: $e');
  }

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
        ChangeNotifierProvider(
          create: (_) => AppUpdateService(),
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
  checkingUpdate,   // Update-Check wird durchgeführt (nur Fire TV)
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
  SplashResult? _pendingSplashResult;

  void _handleSplashComplete(SplashResult result) {
    // On Fire TV, check for updates first
    if (TvUtils.isTvDevice && !kIsWeb && Platform.isAndroid) {
      _pendingSplashResult = result;
      setState(() => _state = _AppState.checkingUpdate);
      _checkForUpdates();
    } else {
      _transitionToState(result);
    }
  }

  Future<void> _checkForUpdates() async {
    final updateService = context.read<AppUpdateService>();
    final updateInfo = await updateService.checkForUpdate();

    if (updateInfo != null && mounted) {
      // Show update dialog
      await UpdateDialog.show(context, updateInfo);
    }

    // Continue with normal flow after update check/dialog
    if (mounted && _pendingSplashResult != null) {
      _transitionToState(_pendingSplashResult!);
    }
  }

  void _transitionToState(SplashResult result) {
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

      case _AppState.checkingUpdate:
        // Show a minimal loading indicator while checking for updates
        return const Scaffold(
          backgroundColor: AppTheme.backgroundDark,
          body: Center(
            child: CircularProgressIndicator(
              color: AppTheme.primaryColor,
            ),
          ),
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
