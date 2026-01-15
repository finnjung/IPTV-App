import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Icon;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart' as material show Icon;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:xtream_code_client/xtream_code_client.dart' hide Image;
import '../services/xtream_service.dart';
import '../models/watch_progress.dart';
import '../models/favorite.dart';
import '../utils/content_parser.dart';
import 'player_screen.dart';

class MovieDetailScreen extends StatelessWidget {
  final XTremeCodeVodItem movie;

  const MovieDetailScreen({super.key, required this.movie});

  Widget _buildBackButton(BuildContext context, double macOSTopPadding) {
    return Padding(
      padding: EdgeInsets.only(top: macOSTopPadding, left: 4),
      child: _FocusableBackButton(
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  bool _isDesktopPlatform() {
    if (kIsWeb) return true;
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final xtreamService = context.watch<XtreamService>();
    final metadata = ContentParser.parse(movie.name ?? 'Film');
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = _isDesktopPlatform() && screenWidth >= 768;

    // macOS Titelleiste Padding
    final isMacOS = !kIsWeb && Platform.isMacOS;
    final macOSTopPadding = isMacOS ? 28.0 : 0.0;

    final contentId = 'movie_${movie.streamId}';
    final isFavorite = xtreamService.isFavorite(contentId);
    final watchProgress = xtreamService.getWatchProgress(contentId);
    final hasProgress = watchProgress != null &&
        watchProgress.position.inSeconds > 30 &&
        watchProgress.duration.inSeconds > 0;

    // Max button width für Desktop
    final maxButtonWidth = isDesktop ? 400.0 : double.infinity;

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // Hero Banner mit Poster
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.6 + macOSTopPadding,
            pinned: true,
            backgroundColor: Colors.black,
            toolbarHeight: kToolbarHeight + macOSTopPadding,
            leading: _buildBackButton(context, macOSTopPadding),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Poster/Backdrop
                  if (movie.streamIcon != null)
                    CachedNetworkImage(
                      imageUrl: movie.streamIcon!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _buildPlaceholder(colorScheme),
                    )
                  else
                    _buildPlaceholder(colorScheme),

                  // Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.7),
                          Colors.black,
                        ],
                        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                      ),
                    ),
                  ),

                  // Title & Info am unteren Rand
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: isDesktop ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                      children: [
                        // Streameee Branding
                        Opacity(
                          opacity: 0.7,
                          child: Text(
                            'streameee',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                            textAlign: isDesktop ? TextAlign.center : TextAlign.left,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Tags
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: isDesktop ? WrapAlignment.center : WrapAlignment.start,
                          children: [
                            if (movie.year != null)
                              _buildTag(movie.year!),
                            if (metadata.quality != null)
                              _buildTag(metadata.quality!, isPrimary: true),
                            if (metadata.language != null)
                              _buildTag(metadata.language!),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Title
                        Text(
                          metadata.cleanName,
                          style: GoogleFonts.poppins(
                            fontSize: isDesktop ? 36 : 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: isDesktop ? TextAlign.center : TextAlign.left,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content - zentriert auf Desktop
          SliverToBoxAdapter(
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxButtonWidth + 40),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Watch Progress Indicator
                    if (hasProgress) ...[
                      _buildProgressBar(watchProgress!, colorScheme),
                      const SizedBox(height: 20),
                    ],

                    // Primary Action Button (Abspielen)
                    SizedBox(
                      width: maxButtonWidth,
                      child: _buildPlayButton(
                        context,
                        xtreamService,
                        watchProgress,
                        hasProgress,
                        colorScheme,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Favoriten Button
                    SizedBox(
                      width: maxButtonWidth,
                      child: _buildFavoriteButton(
                        context,
                        xtreamService,
                        isFavorite,
                        colorScheme,
                      ),
                    ),

                    // Von vorne starten (wenn Progress vorhanden)
                    if (hasProgress) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: maxButtonWidth,
                        child: _buildRestartButton(
                          context,
                          xtreamService,
                          colorScheme,
                        ),
                      ),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(WatchProgress progress, ColorScheme colorScheme) {
    final progressPercent = progress.duration.inSeconds > 0
        ? (progress.position.inSeconds / progress.duration.inSeconds)
        : 0.0;

    final remainingMinutes = ((progress.duration - progress.position).inSeconds / 60).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Weiterschauen',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[400],
              ),
            ),
            Text(
              'Noch $remainingMinutes Min.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progressPercent.clamp(0.0, 1.0),
            backgroundColor: Colors.grey[800],
            valueColor: const AlwaysStoppedAnimation(Colors.red),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  Widget _buildPlayButton(
    BuildContext context,
    XtreamService xtreamService,
    WatchProgress? watchProgress,
    bool hasProgress,
    ColorScheme colorScheme,
  ) {
    return SizedBox(
      width: double.infinity,
      child: _FocusableActionButton(
        autofocus: true,
        isPrimary: true,
        onPressed: () => _play(context, xtreamService, resume: hasProgress),
        icon: SvgPicture.asset(
          'assets/icons/play.svg',
          width: 24,
          height: 24,
          colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
        ),
        focusedIcon: SvgPicture.asset(
          'assets/icons/play.svg',
          width: 24,
          height: 24,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
        ),
        label: hasProgress ? 'Weiterschauen' : 'Abspielen',
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  Widget _buildRestartButton(
    BuildContext context,
    XtreamService xtreamService,
    ColorScheme colorScheme,
  ) {
    return SizedBox(
      width: double.infinity,
      child: _FocusableActionButton(
        onPressed: () => _play(context, xtreamService, resume: false),
        icon: const material.Icon(Icons.refresh, size: 20, color: Colors.white),
        label: 'Von vorne starten',
      ),
    );
  }

  Widget _buildFavoriteButton(
    BuildContext context,
    XtreamService xtreamService,
    bool isFavorite,
    ColorScheme colorScheme,
  ) {
    return _FocusableActionButton(
      onPressed: () {
        final favorite = Favorite.fromMovie(
          streamId: movie.streamId ?? 0,
          title: movie.name ?? '',
          imageUrl: movie.streamIcon,
          extension: movie.containerExtension,
        );
        xtreamService.toggleFavorite(favorite);
      },
      foregroundColor: isFavorite ? Colors.red : Colors.white,
      borderColor: isFavorite ? Colors.red : null,
      icon: material.Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        size: 20,
        color: isFavorite ? Colors.red : Colors.white,
      ),
      label: isFavorite ? 'In Liste' : 'Merken',
    );
  }

  void _play(
    BuildContext context,
    XtreamService xtreamService, {
    required bool resume,
  }) {
    final contentId = 'movie_${movie.streamId}';

    final url = xtreamService.getMovieUrl(
      movie.streamId ?? 0,
      container: movie.containerExtension ?? 'mp4',
    );

    if (url != null) {
      final metadata = ContentParser.parse(movie.name ?? 'Film');

      // Wenn nicht fortsetzen, Progress löschen
      if (!resume) {
        xtreamService.removeWatchProgress(contentId);
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            title: metadata.cleanName,
            subtitle: movie.year,
            streamUrl: url,
            contentId: contentId,
            imageUrl: movie.streamIcon,
            contentType: ContentType.movie,
          ),
        ),
      );
    }
  }

  Widget _buildTag(String text, {bool isPrimary = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPrimary
            ? Colors.blue.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: isPrimary ? Border.all(color: Colors.blue.withValues(alpha: 0.5)) : null,
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isPrimary ? Colors.blue[200] : Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: SvgPicture.asset(
          'assets/icons/film-strip.svg',
          width: 80,
          height: 80,
          colorFilter: ColorFilter.mode(
            Colors.grey[700]!,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}

/// Wrapper widget to navigate to MovieDetailScreen from favorites
/// without needing a full XTremeCodeVodItem
class MovieDetailScreenFromFavorite extends StatefulWidget {
  final int streamId;
  final String movieTitle;
  final String? moviePoster;
  final String? containerExtension;

  const MovieDetailScreenFromFavorite({
    super.key,
    required this.streamId,
    required this.movieTitle,
    this.moviePoster,
    this.containerExtension,
  });

  @override
  State<MovieDetailScreenFromFavorite> createState() => _MovieDetailScreenFromFavoriteState();
}

class _MovieDetailScreenFromFavoriteState extends State<MovieDetailScreenFromFavorite> {
  XTremeCodeVodItem? _movie;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMovie();
  }

  Future<void> _loadMovie() async {
    final xtreamService = context.read<XtreamService>();

    // Try to find the movie in the cached content
    final allMovies = xtreamService.moviesScreenContent?.allMoviesSorted ?? [];
    final movie = allMovies.where((m) => m.streamId == widget.streamId).firstOrNull;

    if (mounted) {
      setState(() {
        _movie = movie;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: Colors.grey[600],
          ),
        ),
      );
    }

    if (_movie == null) {
      // If movie not found in cache, show a simplified detail screen
      return _SimplifiedMovieDetailScreen(
        streamId: widget.streamId,
        movieTitle: widget.movieTitle,
        moviePoster: widget.moviePoster,
        containerExtension: widget.containerExtension,
      );
    }

    return MovieDetailScreen(movie: _movie!);
  }
}

/// Simplified movie detail screen for when we don't have full movie data
class _SimplifiedMovieDetailScreen extends StatelessWidget {
  final int streamId;
  final String movieTitle;
  final String? moviePoster;
  final String? containerExtension;

  const _SimplifiedMovieDetailScreen({
    required this.streamId,
    required this.movieTitle,
    this.moviePoster,
    this.containerExtension,
  });

  bool _isDesktopPlatform() {
    if (kIsWeb) return true;
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  @override
  Widget build(BuildContext context) {
    final xtreamService = context.watch<XtreamService>();
    final metadata = ContentParser.parse(movieTitle);
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = _isDesktopPlatform() && screenWidth >= 768;

    // macOS Titelleiste Padding
    final isMacOS = !kIsWeb && Platform.isMacOS;
    final macOSTopPadding = isMacOS ? 28.0 : 0.0;

    final contentId = 'movie_$streamId';
    final watchProgress = xtreamService.getWatchProgress(contentId);
    final hasProgress = watchProgress != null &&
        watchProgress.position.inSeconds > 30 &&
        watchProgress.duration.inSeconds > 0;

    // Max button width für Desktop
    final maxButtonWidth = isDesktop ? 400.0 : double.infinity;

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          // Hero Banner
          SliverAppBar(
            expandedHeight: MediaQuery.of(context).size.height * 0.6 + macOSTopPadding,
            pinned: true,
            backgroundColor: Colors.black,
            toolbarHeight: kToolbarHeight + macOSTopPadding,
            leading: Padding(
              padding: EdgeInsets.only(top: macOSTopPadding, left: 4),
              child: _FocusableBackButton(
                onPressed: () => Navigator.pop(context),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Poster
                  if (moviePoster != null)
                    CachedNetworkImage(
                      imageUrl: moviePoster!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _buildPlaceholder(),
                    )
                  else
                    _buildPlaceholder(),

                  // Gradient Overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.7),
                          Colors.black,
                        ],
                        stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
                      ),
                    ),
                  ),

                  // Title
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 20,
                    child: Column(
                      crossAxisAlignment: isDesktop ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                      children: [
                        // Streameee Branding
                        Opacity(
                          opacity: 0.7,
                          child: Text(
                            'streameee',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                            textAlign: isDesktop ? TextAlign.center : TextAlign.left,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (metadata.quality != null)
                          _buildTag(metadata.quality!, isPrimary: true),
                        const SizedBox(height: 12),
                        Text(
                          metadata.cleanName,
                          style: GoogleFonts.poppins(
                            fontSize: isDesktop ? 36 : 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: isDesktop ? TextAlign.center : TextAlign.left,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content - zentriert auf Desktop
          SliverToBoxAdapter(
            child: Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: maxButtonWidth + 40),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Progress bar
                    if (hasProgress) ...[
                      _buildProgressBar(watchProgress!),
                      const SizedBox(height: 20),
                    ],

                    // Play Button
                    SizedBox(
                      width: maxButtonWidth,
                      child: _FocusableActionButton(
                        autofocus: true,
                        isPrimary: true,
                        onPressed: () => _play(context, xtreamService, resume: hasProgress),
                        icon: SvgPicture.asset(
                          'assets/icons/play.svg',
                          width: 24,
                          height: 24,
                          colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                        ),
                        focusedIcon: SvgPicture.asset(
                          'assets/icons/play.svg',
                          width: 24,
                          height: 24,
                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                        ),
                        label: hasProgress ? 'Weiterschauen' : 'Abspielen',
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),

                    if (hasProgress) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: maxButtonWidth,
                        child: _FocusableActionButton(
                          onPressed: () => _play(context, xtreamService, resume: false),
                          icon: const material.Icon(Icons.refresh, size: 20, color: Colors.white),
                          label: 'Von vorne starten',
                        ),
                      ),
                    ],

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(WatchProgress progress) {
    final progressPercent = progress.duration.inSeconds > 0
        ? (progress.position.inSeconds / progress.duration.inSeconds)
        : 0.0;
    final remainingMinutes = ((progress.duration - progress.position).inSeconds / 60).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Weiterschauen',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[400],
              ),
            ),
            Text(
              'Noch $remainingMinutes Min.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progressPercent.clamp(0.0, 1.0),
            backgroundColor: Colors.grey[800],
            valueColor: const AlwaysStoppedAnimation(Colors.red),
            minHeight: 4,
          ),
        ),
      ],
    );
  }

  void _play(
    BuildContext context,
    XtreamService xtreamService, {
    required bool resume,
  }) {
    final contentId = 'movie_$streamId';
    final url = xtreamService.getMovieUrl(
      streamId,
      container: containerExtension ?? 'mp4',
    );

    if (url != null) {
      final metadata = ContentParser.parse(movieTitle);

      if (!resume) {
        xtreamService.removeWatchProgress(contentId);
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            title: metadata.cleanName,
            streamUrl: url,
            contentId: contentId,
            imageUrl: moviePoster,
            contentType: ContentType.movie,
          ),
        ),
      );
    }
  }

  Widget _buildTag(String text, {bool isPrimary = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPrimary
            ? Colors.blue.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: isPrimary ? Border.all(color: Colors.blue.withValues(alpha: 0.5)) : null,
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isPrimary ? Colors.blue[200] : Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[900],
      child: Center(
        child: SvgPicture.asset(
          'assets/icons/film-strip.svg',
          width: 80,
          height: 80,
          colorFilter: ColorFilter.mode(
            Colors.grey[700]!,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}

/// Fokussierbarer Zurück-Button mit animiertem Rahmen
class _FocusableBackButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _FocusableBackButton({required this.onPressed});

  @override
  State<_FocusableBackButton> createState() => _FocusableBackButtonState();
}

class _FocusableBackButtonState extends State<_FocusableBackButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _borderAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _borderAnimation = Tween<double>(begin: 0.0, end: 3.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleFocusChange(bool hasFocus) {
    if (hasFocus) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space) {
        widget.onPressed();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: _handleFocusChange,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
                border: _borderAnimation.value > 0
                    ? Border.all(
                        color: Colors.white,
                        width: _borderAnimation.value,
                      )
                    : null,
                boxShadow: _glowAnimation.value > 0
                    ? [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.3 * _glowAnimation.value),
                          blurRadius: 8 * _glowAnimation.value,
                          spreadRadius: 1 * _glowAnimation.value,
                        ),
                      ]
                    : null,
              ),
              child: const material.Icon(Icons.arrow_back, color: Colors.white),
            );
          },
        ),
      ),
    );
  }
}

/// Fokussierbarer Action-Button mit animiertem Rahmen
class _FocusableActionButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget? icon;
  final Widget? focusedIcon;
  final String? label;
  final Widget? child;
  final bool isPrimary;
  final bool autofocus;
  final Color? foregroundColor;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;

  const _FocusableActionButton({
    required this.onPressed,
    this.label,
    this.icon,
    this.focusedIcon,
    this.child,
    this.isPrimary = false,
    this.autofocus = false,
    this.foregroundColor,
    this.borderColor,
    this.padding = const EdgeInsets.symmetric(vertical: 14),
  });

  @override
  State<_FocusableActionButton> createState() => _FocusableActionButtonState();
}

class _FocusableActionButtonState extends State<_FocusableActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _focusAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _focusAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleFocusChange(bool hasFocus) {
    if (hasFocus) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && widget.onPressed != null) {
      if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.space) {
        widget.onPressed!();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // Standard-Werte für unfokussierten Zustand
    final normalBgColor = widget.isPrimary ? Colors.white : Colors.transparent;
    final normalFgColor = widget.foregroundColor ?? (widget.isPrimary ? Colors.black : Colors.white);
    final normalBorderColor = widget.borderColor ?? (widget.isPrimary ? Colors.transparent : Colors.grey[700]!);

    // Fokussierte Werte
    const focusBorderColor = Colors.white;
    const focusFgColor = Colors.white;
    final focusBgColor = Colors.transparent;

    return Focus(
      autofocus: widget.autofocus,
      onFocusChange: _handleFocusChange,
      onKeyEvent: _handleKeyEvent,
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final borderWidth = 1.0 + (_focusAnimation.value * 2.0); // 1 -> 3

            // Animierte Farben für Primary Button
            final currentBgColor = widget.isPrimary
                ? Color.lerp(normalBgColor, focusBgColor, _focusAnimation.value)!
                : normalBgColor;
            final currentFgColor = widget.isPrimary
                ? Color.lerp(normalFgColor, focusFgColor, _focusAnimation.value)!
                : normalFgColor;
            final currentBorderColor = Color.lerp(normalBorderColor, focusBorderColor, _focusAnimation.value)!;

            return Container(
              padding: widget.padding,
              decoration: BoxDecoration(
                color: currentBgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: currentBorderColor,
                  width: borderWidth,
                ),
              ),
              child: widget.child ?? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (widget.icon != null) ...[
                    // Smooth icon crossfade mit Stack und Opacity
                    if (widget.focusedIcon != null)
                      Stack(
                        children: [
                          Opacity(
                            opacity: 1.0 - _focusAnimation.value,
                            child: widget.icon,
                          ),
                          Opacity(
                            opacity: _focusAnimation.value,
                            child: widget.focusedIcon,
                          ),
                        ],
                      )
                    else
                      widget.icon!,
                    const SizedBox(width: 8),
                  ],
                  if (widget.label != null)
                    Text(
                      widget.label!,
                      style: GoogleFonts.poppins(
                        fontSize: widget.isPrimary ? 16 : 14,
                        fontWeight: widget.isPrimary ? FontWeight.w600 : FontWeight.w500,
                        color: currentFgColor,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
