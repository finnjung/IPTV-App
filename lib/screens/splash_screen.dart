import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/xtream_service.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  bool _minTimeElapsed = false;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
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

    // Mindestzeit für Splash (damit Logo sichtbar ist)
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _minTimeElapsed = true);
        _checkAndExit();
      }
    });
  }

  void _checkAndExit() {
    if (_isExiting) return;

    final xtreamService = context.read<XtreamService>();

    // Warte bis: Mindestzeit vorbei UND (nicht connected ODER preloading fertig)
    if (_minTimeElapsed && (!xtreamService.isConnected || !xtreamService.isPreloading)) {
      _isExiting = true;
      // Sanfter Übergang
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          widget.onComplete();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Auf Preloading-Status hören (für _checkAndExit)
    context.watch<XtreamService>();

    // Prüfen ob wir jetzt fertig sind
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndExit();
    });

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
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
