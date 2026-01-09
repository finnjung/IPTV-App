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
import '../screens/player_screen.dart';

class MovieDetailSheet extends StatelessWidget {
  final XTremeCodeVodItem movie;

  const MovieDetailSheet({super.key, required this.movie});

  static void show(BuildContext context, XTremeCodeVodItem movie) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => MovieDetailSheet(movie: movie),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final xtreamService = context.watch<XtreamService>();
    final downloadService = context.watch<DownloadService>();
    final metadata = ContentParser.parse(movie.name ?? 'Film');

    final favoriteId = 'movie_${movie.streamId}';
    final downloadId = 'movie_${movie.streamId}';
    final isFavorite = xtreamService.isFavorite(favoriteId);
    final existingDownload = downloadService.getDownload(downloadId);
    final isDownloaded = existingDownload?.isCompleted ?? false;
    final isDownloading = existingDownload?.isDownloading ?? false;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colorScheme.onSurface.withAlpha(50),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with poster and info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Poster
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 120,
                          height: 180,
                          child: movie.streamIcon != null
                              ? CachedNetworkImage(
                                  imageUrl: movie.streamIcon!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => _buildPlaceholder(colorScheme),
                                )
                              : _buildPlaceholder(colorScheme),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              metadata.cleanName,
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),

                            // Tags
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (movie.year != null)
                                  _buildTag(movie.year!, colorScheme),
                                if (metadata.quality != null)
                                  _buildTag(metadata.quality!, colorScheme, isPrimary: true),
                                if (metadata.language != null)
                                  _buildTag(metadata.language!, colorScheme),
                                if (isDownloaded)
                                  _buildTag('Offline', colorScheme, isSuccess: true),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Favorite button
                            GestureDetector(
                              onTap: () {
                                final favorite = Favorite.fromMovie(
                                  streamId: movie.streamId ?? 0,
                                  title: movie.name ?? '',
                                  imageUrl: movie.streamIcon,
                                  extension: movie.containerExtension,
                                );
                                xtreamService.toggleFavorite(favorite);
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SvgPicture.asset(
                                    isFavorite ? 'assets/icons/heart-fill.svg' : 'assets/icons/heart.svg',
                                    width: 20,
                                    height: 20,
                                    colorFilter: ColorFilter.mode(
                                      isFavorite ? Colors.red : colorScheme.onSurface.withAlpha(150),
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isFavorite ? 'In Favoriten' : 'Zu Favoriten',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: colorScheme.onSurface.withAlpha(180),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      // Play button
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () => _playMovie(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colorScheme.primary,
                            foregroundColor: colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: SvgPicture.asset(
                            'assets/icons/play.svg',
                            width: 20,
                            height: 20,
                            colorFilter: ColorFilter.mode(
                              colorScheme.onPrimary,
                              BlendMode.srcIn,
                            ),
                          ),
                          label: Text(
                            isDownloaded ? 'Offline abspielen' : 'Abspielen',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Download button
                      Expanded(
                        child: _buildDownloadButton(
                          context,
                          existingDownload,
                          downloadService,
                          xtreamService,
                          colorScheme,
                        ),
                      ),
                    ],
                  ),

                  // Download progress
                  if (isDownloading && existingDownload != null) ...[
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Download läuft...',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: colorScheme.onSurface.withAlpha(150),
                              ),
                            ),
                            Text(
                              '${existingDownload.progressPercent}%',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: existingDownload.progress,
                            backgroundColor: colorScheme.onSurface.withAlpha(20),
                            valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadButton(
    BuildContext context,
    Download? existingDownload,
    DownloadService downloadService,
    XtreamService xtreamService,
    ColorScheme colorScheme,
  ) {
    final isDownloaded = existingDownload?.isCompleted ?? false;
    final isDownloading = existingDownload?.isDownloading ?? false;
    final isPending = existingDownload?.isPending ?? false;
    final isPaused = existingDownload?.isPaused ?? false;

    IconData icon;
    String tooltip;
    VoidCallback? onPressed;

    if (isDownloaded) {
      icon = Icons.check_circle;
      tooltip = 'Heruntergeladen';
      onPressed = () => _showDeleteDialog(context, downloadService, existingDownload!);
    } else if (isDownloading) {
      icon = Icons.pause;
      tooltip = 'Pausieren';
      onPressed = () => downloadService.pauseDownload(existingDownload!.id);
    } else if (isPending) {
      icon = Icons.schedule;
      tooltip = 'Wartend';
      onPressed = () => downloadService.cancelDownload(existingDownload!.id);
    } else if (isPaused) {
      icon = Icons.play_arrow;
      tooltip = 'Fortsetzen';
      onPressed = () => downloadService.resumeDownload(existingDownload!.id);
    } else {
      icon = Icons.download_rounded;
      tooltip = 'Herunterladen';
      onPressed = () => _startDownload(context, xtreamService, downloadService);
    }

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: BorderSide(
          color: isDownloaded ? Colors.green : colorScheme.outline.withAlpha(50),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: material.Icon(
        icon,
        color: isDownloaded ? Colors.green : colorScheme.onSurface,
      ),
    );
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
          content: Text('Download gestartet: ${metadata.cleanName}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showDeleteDialog(
    BuildContext context,
    DownloadService downloadService,
    Download download,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Download löschen?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          '${download.title} wird gelöscht.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () {
              downloadService.deleteDownload(download.id);
              Navigator.pop(context);
            },
            child: const Text(
              'Löschen',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _playMovie(BuildContext context) {
    final xtreamService = context.read<XtreamService>();
    final downloadService = context.read<DownloadService>();
    final downloadId = 'movie_${movie.streamId}';

    // Prüfe ob offline verfügbar
    final localPath = downloadService.getLocalPath(downloadId);
    final url = localPath ?? xtreamService.getMovieUrl(
      movie.streamId ?? 0,
      container: movie.containerExtension ?? 'mp4',
    );

    if (url != null) {
      final metadata = ContentParser.parse(movie.name ?? 'Film');
      Navigator.pop(context); // Close sheet
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            title: metadata.cleanName,
            subtitle: movie.year,
            streamUrl: url,
            contentId: downloadId,
            imageUrl: movie.streamIcon,
            contentType: ContentType.movie,
          ),
        ),
      );
    }
  }

  Widget _buildTag(String text, ColorScheme colorScheme, {bool isPrimary = false, bool isSuccess = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isSuccess
            ? Colors.green.withAlpha(30)
            : isPrimary
                ? colorScheme.primary.withAlpha(30)
                : colorScheme.onSurface.withAlpha(15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isSuccess
              ? Colors.green
              : isPrimary
                  ? colorScheme.primary
                  : colorScheme.onSurface.withAlpha(180),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.onSurface.withAlpha(10),
      child: Center(
        child: SvgPicture.asset(
          'assets/icons/film-strip.svg',
          width: 40,
          height: 40,
          colorFilter: ColorFilter.mode(
            colorScheme.onSurface.withAlpha(30),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}
