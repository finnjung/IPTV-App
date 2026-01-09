import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Icon;
import 'package:flutter/material.dart' as material show Icon;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:xtream_code_client/xtream_code_client.dart';
import '../services/xtream_service.dart';
import '../services/download_service.dart';
import '../models/download.dart';
import '../models/watch_progress.dart';
import '../models/favorite.dart';
import '../utils/content_parser.dart';
import 'player_screen.dart';

class MovieDetailScreen extends StatelessWidget {
  final XTremeCodeVodItem movie;

  const MovieDetailScreen({super.key, required this.movie});

  bool _isDesktopPlatform() {
    if (kIsWeb) return true;
    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final xtreamService = context.watch<XtreamService>();
    final downloadService = context.watch<DownloadService>();
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

    final download = downloadService.getDownload(contentId);
    final isDownloaded = download?.isCompleted ?? false;
    final isDownloading = download?.isDownloading ?? false;
    final downloadProgress = download?.progress ?? 0.0;

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
            leading: Padding(
              padding: EdgeInsets.only(top: macOSTopPadding),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const material.Icon(Icons.arrow_back, color: Colors.white),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
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

                  // Download Badge
                  if (isDownloaded)
                    Positioned(
                      top: MediaQuery.of(context).padding.top + macOSTopPadding + 8,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            material.Icon(Icons.download_done, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            const Text(
                              'Heruntergeladen',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
                        downloadService,
                        watchProgress,
                        hasProgress,
                        isDownloaded,
                        colorScheme,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Secondary Actions Row
                    SizedBox(
                      width: maxButtonWidth,
                      child: Row(
                        children: [
                          // Download Button
                          Expanded(
                            child: _buildDownloadButton(
                              context,
                              xtreamService,
                              downloadService,
                              download,
                              isDownloaded,
                              isDownloading,
                              downloadProgress,
                              colorScheme,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Favoriten Button
                          Expanded(
                            child: _buildFavoriteButton(
                              context,
                              xtreamService,
                              isFavorite,
                              colorScheme,
                            ),
                          ),
                        ],
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
                          downloadService,
                          isDownloaded,
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
    DownloadService downloadService,
    WatchProgress? watchProgress,
    bool hasProgress,
    bool isDownloaded,
    ColorScheme colorScheme,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _play(context, xtreamService, downloadService, isDownloaded, resume: hasProgress),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: SvgPicture.asset(
          'assets/icons/play.svg',
          width: 24,
          height: 24,
          colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
        ),
        label: Text(
          hasProgress ? 'Weiterschauen' : 'Abspielen',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildRestartButton(
    BuildContext context,
    XtreamService xtreamService,
    DownloadService downloadService,
    bool isDownloaded,
    ColorScheme colorScheme,
  ) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _play(context, xtreamService, downloadService, isDownloaded, resume: false),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: Colors.grey[700]!),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: const material.Icon(Icons.refresh, size: 20),
        label: Text(
          'Von vorne starten',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadButton(
    BuildContext context,
    XtreamService xtreamService,
    DownloadService downloadService,
    Download? download,
    bool isDownloaded,
    bool isDownloading,
    double downloadProgress,
    ColorScheme colorScheme,
  ) {
    if (isDownloading) {
      return OutlinedButton(
        onPressed: () => downloadService.pauseDownload(download!.id),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: Colors.grey[700]!),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                value: downloadProgress,
                strokeWidth: 2,
                valueColor: const AlwaysStoppedAnimation(Colors.blue),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${(downloadProgress * 100).round()}%',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (isDownloaded) {
      return OutlinedButton.icon(
        onPressed: () => _showDownloadOptions(context, downloadService, download!),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: Colors.green),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: const material.Icon(Icons.check_circle, size: 20),
        label: Text(
          'Geladen',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => _startDownload(context, xtreamService, downloadService),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: Colors.grey[700]!),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      icon: const material.Icon(Icons.download_rounded, size: 20),
      label: Text(
        'Download',
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildFavoriteButton(
    BuildContext context,
    XtreamService xtreamService,
    bool isFavorite,
    ColorScheme colorScheme,
  ) {
    return OutlinedButton.icon(
      onPressed: () {
        final favorite = Favorite.fromMovie(
          streamId: movie.streamId ?? 0,
          title: movie.name ?? '',
          imageUrl: movie.streamIcon,
          extension: movie.containerExtension,
        );
        xtreamService.toggleFavorite(favorite);
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: isFavorite ? Colors.red : Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: isFavorite ? Colors.red : Colors.grey[700]!),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      icon: material.Icon(
        isFavorite ? Icons.favorite : Icons.favorite_border,
        size: 20,
      ),
      label: Text(
        isFavorite ? 'In Liste' : 'Merken',
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _play(
    BuildContext context,
    XtreamService xtreamService,
    DownloadService downloadService,
    bool isDownloaded, {
    required bool resume,
  }) {
    final contentId = 'movie_${movie.streamId}';

    // Lokaler Pfad wenn heruntergeladen
    final localPath = downloadService.getLocalPath(contentId);
    final url = localPath ?? xtreamService.getMovieUrl(
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

  void _startDownload(
    BuildContext context,
    XtreamService xtreamService,
    DownloadService downloadService,
  ) {
    final url = xtreamService.getMovieUrl(
      movie.streamId ?? 0,
      container: movie.containerExtension ?? 'mp4',
    );

    if (url != null) {
      final metadata = ContentParser.parse(movie.name ?? 'Film');
      final download = Download.fromMovie(
        streamId: movie.streamId ?? 0,
        title: metadata.cleanName,
        sourceUrl: url,
        imageUrl: movie.streamIcon,
        extension: movie.containerExtension ?? 'mp4',
      );
      downloadService.addDownload(download);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              material.Icon(Icons.download_rounded, color: Colors.blue, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Download gestartet',
                  style: TextStyle(color: Colors.grey[200]),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.grey[850],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showDownloadOptions(
    BuildContext context,
    DownloadService downloadService,
    Download download,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            ListTile(
              leading: const material.Icon(Icons.save_alt, color: Colors.white),
              title: Text(
                'In Downloads-Ordner exportieren',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
              onTap: () async {
                Navigator.pop(context);
                final path = await downloadService.exportDownload(download.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        path != null ? 'Exportiert!' : 'Export fehlgeschlagen',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),

            ListTile(
              leading: const material.Icon(Icons.delete_outline, color: Colors.red),
              title: Text(
                'Download löschen',
                style: GoogleFonts.poppins(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(context);
                downloadService.deleteDownload(download.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Download gelöscht'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),

            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
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
    final downloadService = context.watch<DownloadService>();
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

    final download = downloadService.getDownload(contentId);
    final isDownloaded = download?.isCompleted ?? false;

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
              padding: EdgeInsets.only(top: macOSTopPadding),
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const material.Icon(Icons.arrow_back, color: Colors.white),
                ),
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
                      child: ElevatedButton.icon(
                        onPressed: () => _play(context, xtreamService, downloadService, isDownloaded, resume: hasProgress),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: SvgPicture.asset(
                          'assets/icons/play.svg',
                          width: 24,
                          height: 24,
                          colorFilter: const ColorFilter.mode(Colors.black, BlendMode.srcIn),
                        ),
                        label: Text(
                          hasProgress ? 'Weiterschauen' : 'Abspielen',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    if (hasProgress) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: maxButtonWidth,
                        child: OutlinedButton.icon(
                          onPressed: () => _play(context, xtreamService, downloadService, isDownloaded, resume: false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: Colors.grey[700]!),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const material.Icon(Icons.refresh, size: 20),
                          label: Text(
                            'Von vorne starten',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
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
    XtreamService xtreamService,
    DownloadService downloadService,
    bool isDownloaded, {
    required bool resume,
  }) {
    final contentId = 'movie_$streamId';
    final localPath = downloadService.getLocalPath(contentId);
    final url = localPath ?? xtreamService.getMovieUrl(
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
