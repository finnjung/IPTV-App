import 'package:flutter/material.dart' hide Icon;
import 'package:flutter/material.dart' as material show Icon;
import 'package:provider/provider.dart';
import 'package:xtream_code_client/xtream_code_client.dart';
import '../services/xtream_service.dart';
import '../services/download_service.dart';
import '../models/download.dart';
import '../utils/content_parser.dart';

class EpisodeDownloadButton extends StatelessWidget {
  final int seriesId;
  final String seriesName;
  final String? seriesCover;
  final XTremeCodeEpisode episode;
  final int seasonNumber;

  const EpisodeDownloadButton({
    super.key,
    required this.seriesId,
    required this.seriesName,
    this.seriesCover,
    required this.episode,
    required this.seasonNumber,
  });

  @override
  Widget build(BuildContext context) {
    final downloadService = context.watch<DownloadService>();
    final downloadId = 'series_${seriesId}_${seasonNumber}_${episode.episodeNum ?? 0}';
    final download = downloadService.getDownload(downloadId);

    final isDownloaded = download?.isCompleted ?? false;
    final isDownloading = download?.isDownloading ?? false;
    final isPending = download?.isPending ?? false;
    final isPaused = download?.isPaused ?? false;

    if (isDownloading) {
      return SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: download?.progress,
              strokeWidth: 2,
              valueColor: const AlwaysStoppedAnimation(Colors.blue),
            ),
            GestureDetector(
              onTap: () => downloadService.pauseDownload(downloadId),
              child: const material.Icon(Icons.pause, size: 14, color: Colors.blue),
            ),
          ],
        ),
      );
    }

    IconData icon;
    Color color;
    VoidCallback? onTap;

    if (isDownloaded) {
      icon = Icons.check_circle;
      color = Colors.green;
      onTap = () => _showDeleteDialog(context, downloadService, download!);
    } else if (isPending) {
      icon = Icons.schedule;
      color = Colors.grey;
      onTap = () => downloadService.cancelDownload(downloadId);
    } else if (isPaused) {
      icon = Icons.play_arrow;
      color = Colors.orange;
      onTap = () => downloadService.resumeDownload(downloadId);
    } else {
      icon = Icons.download_rounded;
      color = Colors.grey.shade400;
      onTap = () => _startDownload(context);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: material.Icon(icon, size: 20, color: color),
      ),
    );
  }

  void _startDownload(BuildContext context) {
    final xtreamService = context.read<XtreamService>();
    final downloadService = context.read<DownloadService>();
    final metadata = ContentParser.parse(seriesName);

    final url = xtreamService.getSeriesEpisodeUrl(
      episode.id ?? 0,
      container: episode.containerExtension ?? 'mp4',
    );

    if (url != null) {
      final download = Download.fromSeriesEpisode(
        seriesId: seriesId,
        seriesName: metadata.cleanName,
        seasonNum: seasonNumber,
        episodeNum: episode.episodeNum ?? 0,
        episodeTitle: episode.title ?? 'Episode ${episode.episodeNum}',
        sourceUrl: url,
        imageUrl: episode.info.movieImage ?? seriesCover,
        extension: episode.containerExtension ?? 'mp4',
      );
      downloadService.addDownload(download);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download gestartet: ${episode.title}'),
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
}

class SeasonDownloadButton extends StatelessWidget {
  final int seriesId;
  final String seriesName;
  final String? seriesCover;
  final int seasonNumber;
  final List<XTremeCodeEpisode> episodes;

  const SeasonDownloadButton({
    super.key,
    required this.seriesId,
    required this.seriesName,
    this.seriesCover,
    required this.seasonNumber,
    required this.episodes,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final downloadService = context.watch<DownloadService>();

    if (episodes.isEmpty) return const SizedBox();

    // Prüfe wie viele Episoden bereits heruntergeladen sind
    int downloadedCount = 0;
    int downloadingCount = 0;
    for (final episode in episodes) {
      final downloadId = 'series_${seriesId}_${seasonNumber}_${episode.episodeNum ?? 0}';
      final download = downloadService.getDownload(downloadId);
      if (download?.isCompleted ?? false) {
        downloadedCount++;
      } else if (download?.isDownloading ?? false) {
        downloadingCount++;
      }
    }

    final allDownloaded = downloadedCount == episodes.length;
    final isDownloading = downloadingCount > 0;

    return OutlinedButton.icon(
      onPressed: allDownloaded
          ? null
          : () => _downloadSeason(context),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        side: BorderSide(
          color: allDownloaded
              ? Colors.green.withAlpha(100)
              : colorScheme.outline.withAlpha(50),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      icon: material.Icon(
        allDownloaded
            ? Icons.check_circle
            : isDownloading
                ? Icons.downloading
                : Icons.download_rounded,
        size: 20,
        color: allDownloaded ? Colors.green : colorScheme.onSurface.withAlpha(180),
      ),
      label: Text(
        allDownloaded
            ? 'Staffel heruntergeladen'
            : isDownloading
                ? 'Download läuft ($downloadedCount/${episodes.length})'
                : 'Staffel herunterladen (${episodes.length} Episoden)',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: allDownloaded ? Colors.green : colorScheme.onSurface.withAlpha(180),
        ),
      ),
    );
  }

  void _downloadSeason(BuildContext context) {
    final xtreamService = context.read<XtreamService>();
    final downloadService = context.read<DownloadService>();
    final metadata = ContentParser.parse(seriesName);
    final downloads = <Download>[];

    for (final episode in episodes) {
      final downloadId = 'series_${seriesId}_${seasonNumber}_${episode.episodeNum ?? 0}';

      // Überspringe bereits existierende Downloads
      if (downloadService.hasDownload(downloadId)) continue;

      final url = xtreamService.getSeriesEpisodeUrl(
        episode.id ?? 0,
        container: episode.containerExtension ?? 'mp4',
      );

      if (url != null) {
        downloads.add(Download.fromSeriesEpisode(
          seriesId: seriesId,
          seriesName: metadata.cleanName,
          seasonNum: seasonNumber,
          episodeNum: episode.episodeNum ?? 0,
          episodeTitle: episode.title ?? 'Episode ${episode.episodeNum}',
          sourceUrl: url,
          imageUrl: episode.info.movieImage ?? seriesCover,
          extension: episode.containerExtension ?? 'mp4',
        ));
      }
    }

    if (downloads.isNotEmpty) {
      downloadService.addDownloads(downloads);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${downloads.length} Episoden werden heruntergeladen'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
