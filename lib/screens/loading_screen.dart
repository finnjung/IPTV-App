import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/xtream_service.dart';
import '../theme/app_theme.dart';

/// Fullscreen loading screen that shows content preload progress
class LoadingScreen extends StatelessWidget {
  final VoidCallback onComplete;

  const LoadingScreen({super.key, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final xtreamService = context.watch<XtreamService>();
    final progress = xtreamService.preloadProgress;
    final status = xtreamService.preloadStatus;
    final isPreloading = xtreamService.isPreloading;

    // Auto-navigate when preloading is done
    if (!isPreloading && progress >= 1.0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onComplete();
      });
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Image.asset(
                'assets/images/streameee-logo.png',
                height: 80,
              ),
              const SizedBox(height: 64),

              // Status text
              Text(
                status.isEmpty ? 'Lade Inhalte...' : status,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),

              // Progress bar
              SizedBox(
                width: 400,
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.white.withAlpha(30),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withAlpha(200),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.white.withAlpha(150),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Loading hint
              Text(
                'Filme, Serien und Live TV werden geladen...',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white.withAlpha(100),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
