import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/download_service.dart';
import '../models/download.dart';
import 'player_screen.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Downloads',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Consumer<DownloadService>(
            builder: (context, service, _) {
              if (service.downloads.isEmpty) return const SizedBox();
              return PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                color: Colors.grey[900],
                onSelected: (value) async {
                  if (value == 'clear_completed') {
                    final confirm = await _showConfirmDialog(
                      context,
                      'Abgeschlossene löschen?',
                      'Alle abgeschlossenen Downloads werden gelöscht.',
                    );
                    if (confirm == true) {
                      service.clearCompletedDownloads();
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'clear_completed',
                    child: Text(
                      'Abgeschlossene löschen',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer<DownloadService>(
        builder: (context, service, _) {
          if (service.downloads.isEmpty) {
            return _buildEmptyState();
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Speicherplatz-Info
              _buildStorageInfo(service),
              const SizedBox(height: 24),

              // Aktive Downloads
              if (service.activeDownloads.isNotEmpty ||
                  service.pendingDownloads.isNotEmpty) ...[
                _buildSectionHeader('Aktive Downloads'),
                const SizedBox(height: 12),
                ...service.activeDownloads.map((d) => _buildDownloadCard(context, d, service)),
                ...service.pendingDownloads.map((d) => _buildDownloadCard(context, d, service)),
                const SizedBox(height: 24),
              ],

              // Filme
              if (service.movieDownloads.where((d) => d.isCompleted).isNotEmpty) ...[
                _buildSectionHeader('Filme'),
                const SizedBox(height: 12),
                ...service.movieDownloads
                    .where((d) => d.isCompleted)
                    .map((d) => _buildDownloadCard(context, d, service)),
                const SizedBox(height: 24),
              ],

              // Serien (gruppiert)
              if (service.seriesDownloadsGrouped.isNotEmpty) ...[
                _buildSectionHeader('Serien'),
                const SizedBox(height: 12),
                ...service.seriesDownloadsGrouped.entries.map(
                  (entry) => _buildSeriesGroup(context, entry.value, service),
                ),
              ],

              // Fehlgeschlagene Downloads
              if (service.downloads.where((d) => d.isFailed).isNotEmpty) ...[
                _buildSectionHeader('Fehlgeschlagen'),
                const SizedBox(height: 12),
                ...service.downloads
                    .where((d) => d.isFailed)
                    .map((d) => _buildDownloadCard(context, d, service)),
              ],

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.download_rounded,
            size: 80,
            color: Colors.grey[700],
          ),
          const SizedBox(height: 16),
          Text(
            'Keine Downloads',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lade Filme und Serien herunter,\num sie offline anzusehen.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageInfo(DownloadService service) {
    final completedCount = service.completedDownloads.length;
    final activeCount = service.activeDownloads.length + service.pendingDownloads.length;
    final totalBytes = service.totalDownloadedBytes;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.smartphone_rounded,
                  color: Colors.blue,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          service.formattedTotalSize,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'In App',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$completedCount Downloads${activeCount > 0 ? ' · $activeCount aktiv' : ''}',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (totalBytes > 0) ...[
            const SizedBox(height: 16),
            // Speicherbalken-Visualisierung
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Offline-Speicher',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      service.formattedTotalSize,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    // Visualisierung basierend auf 10GB als "voll"
                    value: (totalBytes / (10 * 1024 * 1024 * 1024)).clamp(0.0, 1.0),
                    backgroundColor: Colors.grey[800],
                    valueColor: const AlwaysStoppedAnimation(Colors.blue),
                    minHeight: 6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Downloads werden sicher in der App gespeichert',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildDownloadCard(
    BuildContext context,
    Download download,
    DownloadService service,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: download.isCompleted
            ? () => _playDownload(context, download)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 80,
                  height: 120,
                  child: download.imageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: download.imageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: Colors.grey[800],
                            child: const Icon(Icons.movie, color: Colors.grey),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey[800],
                            child: const Icon(Icons.movie, color: Colors.grey),
                          ),
                        )
                      : Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.movie, color: Colors.grey),
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      download.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (download.subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        download.subtitle!,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),

                    // Status / Progress
                    if (download.isDownloading) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: download.progress,
                          backgroundColor: Colors.grey[800],
                          valueColor: const AlwaysStoppedAnimation(Colors.blue),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        download.formattedProgress,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Icon(
                            _getStatusIcon(download.status),
                            size: 16,
                            color: _getStatusColor(download.status),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            download.statusText,
                            style: TextStyle(
                              color: _getStatusColor(download.status),
                              fontSize: 12,
                            ),
                          ),
                          if (download.isCompleted) ...[
                            const SizedBox(width: 8),
                            Text(
                              download.formattedSize,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Actions
              _buildActionButton(context, download, service),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    Download download,
    DownloadService service,
  ) {
    if (download.isDownloading) {
      return IconButton(
        icon: const Icon(Icons.pause_rounded, color: Colors.white),
        onPressed: () => service.pauseDownload(download.id),
      );
    } else if (download.isPaused || download.isFailed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.play_arrow_rounded, color: Colors.blue),
            onPressed: () => service.resumeDownload(download.id),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.grey[400]),
            onPressed: () async {
              final confirm = await _showConfirmDialog(
                context,
                'Download löschen?',
                '${download.title} wird gelöscht.',
              );
              if (confirm == true) {
                service.deleteDownload(download.id);
              }
            },
          ),
        ],
      );
    } else if (download.isPending) {
      return IconButton(
        icon: Icon(Icons.close, color: Colors.grey[400]),
        onPressed: () => service.cancelDownload(download.id),
      );
    } else if (download.isCompleted) {
      return PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, color: Colors.grey[400]),
        color: Colors.grey[900],
        onSelected: (value) async {
          if (value == 'delete') {
            final confirm = await _showConfirmDialog(
              context,
              'Download löschen?',
              '${download.title} wird gelöscht.',
            );
            if (confirm == true) {
              service.deleteDownload(download.id);
            }
          } else if (value == 'export') {
            _exportDownload(context, service, download);
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'export',
            child: Row(
              children: [
                Icon(Icons.save_alt, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text(
                  'In Downloads speichern',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete_outline, color: Colors.red, size: 20),
                SizedBox(width: 12),
                Text(
                  'Löschen',
                  style: TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return const SizedBox();
  }

  Widget _buildSeriesGroup(
    BuildContext context,
    List<Download> episodes,
    DownloadService service,
  ) {
    if (episodes.isEmpty) return const SizedBox();

    final firstEpisode = episodes.first;
    final completedEpisodes = episodes.where((e) => e.isCompleted).length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: ThemeData(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 60,
              height: 90,
              child: firstEpisode.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: firstEpisode.imageUrl!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.grey[800],
                      child: const Icon(Icons.tv, color: Colors.grey),
                    ),
            ),
          ),
          title: Text(
            firstEpisode.seriesName ?? 'Serie',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '$completedEpisodes von ${episodes.length} Episoden',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
          iconColor: Colors.grey[400],
          collapsedIconColor: Colors.grey[400],
          children: episodes.map((episode) {
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              title: Text(
                episode.subtitle ?? episode.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                episode.statusText,
                style: TextStyle(
                  color: _getStatusColor(episode.status),
                  fontSize: 12,
                ),
              ),
              trailing: episode.isCompleted
                  ? IconButton(
                      icon: const Icon(Icons.play_circle_fill, color: Colors.blue),
                      onPressed: () => _playDownload(context, episode),
                    )
                  : episode.isDownloading
                      ? SizedBox(
                          width: 40,
                          height: 40,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: episode.progress,
                                strokeWidth: 2,
                                valueColor: const AlwaysStoppedAnimation(Colors.blue),
                              ),
                              Text(
                                '${episode.progressPercent}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Icon(
                          _getStatusIcon(episode.status),
                          color: _getStatusColor(episode.status),
                        ),
              onTap: episode.isCompleted
                  ? () => _playDownload(context, episode)
                  : null,
            );
          }).toList(),
        ),
      ),
    );
  }

  IconData _getStatusIcon(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.pending:
        return Icons.schedule;
      case DownloadStatus.downloading:
        return Icons.downloading;
      case DownloadStatus.paused:
        return Icons.pause;
      case DownloadStatus.completed:
        return Icons.check_circle;
      case DownloadStatus.failed:
        return Icons.error;
    }
  }

  Color _getStatusColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.pending:
        return Colors.grey;
      case DownloadStatus.downloading:
        return Colors.blue;
      case DownloadStatus.paused:
        return Colors.orange;
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.failed:
        return Colors.red;
    }
  }

  void _playDownload(BuildContext context, Download download) {
    if (download.localPath == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlayerScreen(
          title: download.title,
          subtitle: download.subtitle,
          streamUrl: download.localPath!,
          contentId: download.id,
          contentType: download.contentType,
        ),
      ),
    );
  }

  Future<void> _exportDownload(
    BuildContext context,
    DownloadService service,
    Download download,
  ) async {
    // Zeige Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    final exportPath = await service.exportDownload(download.id);

    if (!context.mounted) return;
    Navigator.pop(context); // Loading schließen

    if (exportPath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Gespeichert in Downloads-Ordner',
                  style: TextStyle(color: Colors.grey[200]),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.grey[850],
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Export fehlgeschlagen',
                  style: TextStyle(color: Colors.grey[200]),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.grey[850],
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool?> _showConfirmDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
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
