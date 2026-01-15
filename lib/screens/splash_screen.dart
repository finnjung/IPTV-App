import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../services/xtream_service.dart';

/// Ergebnis des Splash-Screen Checks
enum SplashResult {
  needsOnboarding,  // User muss durch Onboarding
  readyWithLoading, // User eingeloggt, aber langsames Laden (API)
  ready,            // User eingeloggt, schnelles Laden (Cache) - alles fertig
}

class SplashScreen extends StatefulWidget {
  final void Function(SplashResult result) onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _scaleAnimation;

  bool _minTimeElapsed = false;
  bool _isExiting = false;
  bool? _needsOnboarding;
  bool _loadingCheckDone = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    // Check onboarding status
    _checkOnboardingStatus();

    // Mindestzeit für Splash (damit Logo sichtbar ist)
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _minTimeElapsed = true);
        _checkAndExit();
      }
    });
  }

  Future<void> _checkOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('onboarding_completed') ?? false;
    if (mounted) {
      setState(() => _needsOnboarding = !completed);
      _checkAndExit();
    }
  }

  void _checkAndExit() {
    if (_isExiting || !_minTimeElapsed || _needsOnboarding == null) return;

    // Wenn Onboarding nötig ist, sofort zum Onboarding
    if (_needsOnboarding!) {
      _exitWithResult(SplashResult.needsOnboarding);
      return;
    }

    // Wenn kein Onboarding nötig, warte auf Preloading-Status
    _waitForLoadingStatus();
  }

  void _waitForLoadingStatus() {
    if (_loadingCheckDone) return;
    _loadingCheckDone = true;

    // Listener für XtreamService um auf Preloading zu warten
    final xtreamService = context.read<XtreamService>();

    // Prüfe sofort den aktuellen Status
    _handleLoadingStatus(xtreamService);

    // Falls noch am Laden, warte auf Änderungen
    if (xtreamService.isPreloading) {
      xtreamService.addListener(_onXtreamServiceChanged);
    }
  }

  void _onXtreamServiceChanged() {
    final xtreamService = context.read<XtreamService>();
    _handleLoadingStatus(xtreamService);
  }

  void _handleLoadingStatus(XtreamService xtreamService) {
    if (_isExiting) return;

    // Noch am Laden?
    if (xtreamService.isPreloading) {
      // Bei Cache-Load (schnell) warten wir hier
      // Bei API-Load (langsam) wechseln wir zum LoadingScreen
      if (!xtreamService.isLoadingFromCache && xtreamService.preloadProgress > 0.05) {
        // API-Load erkannt und läuft schon - zeige LoadingScreen
        xtreamService.removeListener(_onXtreamServiceChanged);
        _exitWithResult(SplashResult.readyWithLoading);
      }
      // Sonst weiter warten (Cache-Load ist schnell)
      return;
    }

    // Preloading fertig - smooth zum Start Screen
    xtreamService.removeListener(_onXtreamServiceChanged);
    _exitWithResult(SplashResult.ready);
  }

  void _exitWithResult(SplashResult result) {
    if (_isExiting) return;
    _isExiting = true;

    // Fade-out Animation
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onComplete(result);
      }
    });
  }

  @override
  void dispose() {
    // Cleanup listener
    try {
      context.read<XtreamService>().removeListener(_onXtreamServiceChanged);
    } catch (_) {}
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeInAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            );
          },
          child: Image.asset(
            'assets/images/streameee-logo.png',
            width: 120,
            height: 120,
          ),
        ),
      ),
    );
  }
}
