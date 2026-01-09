import 'dart:convert';
import 'watch_progress.dart'; // Für ContentType enum

enum DownloadStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
}

class Download {
  final String id; // Unique: movie_streamId | series_seriesId_seasonNum_episodeNum
  final String title;
  final String? subtitle; // z.B. "S01 E05" für Serien
  final String sourceUrl;
  final String? imageUrl;
  final ContentType contentType;
  final String? localPath; // Pfad zur heruntergeladenen Datei
  final String? extension; // mp4, mkv, etc.

  // Progress tracking
  final int totalBytes;
  final int downloadedBytes;
  final DateTime createdAt;
  final DateTime? completedAt;

  // Status
  final DownloadStatus status;
  final String? errorMessage;

  // Für Serien
  final int? seriesId;
  final int? seasonNum;
  final int? episodeNum;
  final String? seriesName; // Name der Serie für Gruppierung

  // Für Filme
  final int? streamId;

  Download({
    required this.id,
    required this.title,
    this.subtitle,
    required this.sourceUrl,
    this.imageUrl,
    required this.contentType,
    this.localPath,
    this.extension,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    required this.createdAt,
    this.completedAt,
    this.status = DownloadStatus.pending,
    this.errorMessage,
    this.seriesId,
    this.seasonNum,
    this.episodeNum,
    this.seriesName,
    this.streamId,
  });

  double get progress => totalBytes > 0
      ? (downloadedBytes / totalBytes).clamp(0.0, 1.0)
      : 0.0;

  int get progressPercent => (progress * 100).round();

  bool get isCompleted => status == DownloadStatus.completed;
  bool get isDownloading => status == DownloadStatus.downloading;
  bool get isPaused => status == DownloadStatus.paused;
  bool get isFailed => status == DownloadStatus.failed;
  bool get isPending => status == DownloadStatus.pending;

  String get formattedSize {
    if (totalBytes == 0) return 'Unbekannt';

    const kb = 1024;
    const mb = kb * 1024;
    const gb = mb * 1024;

    if (totalBytes >= gb) {
      return '${(totalBytes / gb).toStringAsFixed(2)} GB';
    } else if (totalBytes >= mb) {
      return '${(totalBytes / mb).toStringAsFixed(1)} MB';
    } else {
      return '${(totalBytes / kb).toStringAsFixed(0)} KB';
    }
  }

  String get formattedProgress {
    if (totalBytes == 0) return '';

    const mb = 1024 * 1024;
    final downloadedMB = downloadedBytes / mb;
    final totalMB = totalBytes / mb;

    return '${downloadedMB.toStringAsFixed(1)} / ${totalMB.toStringAsFixed(1)} MB';
  }

  String get statusText {
    switch (status) {
      case DownloadStatus.pending:
        return 'Wartend';
      case DownloadStatus.downloading:
        return 'Lädt... $progressPercent%';
      case DownloadStatus.paused:
        return 'Pausiert';
      case DownloadStatus.completed:
        return 'Abgeschlossen';
      case DownloadStatus.failed:
        return errorMessage ?? 'Fehlgeschlagen';
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'sourceUrl': sourceUrl,
    'imageUrl': imageUrl,
    'contentType': contentType.index,
    'localPath': localPath,
    'extension': extension,
    'totalBytes': totalBytes,
    'downloadedBytes': downloadedBytes,
    'createdAt': createdAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
    'status': status.index,
    'errorMessage': errorMessage,
    'seriesId': seriesId,
    'seasonNum': seasonNum,
    'episodeNum': episodeNum,
    'seriesName': seriesName,
    'streamId': streamId,
  };

  factory Download.fromJson(Map<String, dynamic> json) => Download(
    id: json['id'],
    title: json['title'],
    subtitle: json['subtitle'],
    sourceUrl: json['sourceUrl'],
    imageUrl: json['imageUrl'],
    contentType: ContentType.values[json['contentType']],
    localPath: json['localPath'],
    extension: json['extension'],
    totalBytes: json['totalBytes'] ?? 0,
    downloadedBytes: json['downloadedBytes'] ?? 0,
    createdAt: DateTime.parse(json['createdAt']),
    completedAt: json['completedAt'] != null
        ? DateTime.parse(json['completedAt'])
        : null,
    status: DownloadStatus.values[json['status']],
    errorMessage: json['errorMessage'],
    seriesId: json['seriesId'],
    seasonNum: json['seasonNum'],
    episodeNum: json['episodeNum'],
    seriesName: json['seriesName'],
    streamId: json['streamId'],
  );

  Download copyWith({
    String? localPath,
    int? totalBytes,
    int? downloadedBytes,
    DownloadStatus? status,
    String? errorMessage,
    DateTime? completedAt,
  }) => Download(
    id: id,
    title: title,
    subtitle: subtitle,
    sourceUrl: sourceUrl,
    imageUrl: imageUrl,
    contentType: contentType,
    localPath: localPath ?? this.localPath,
    extension: extension,
    totalBytes: totalBytes ?? this.totalBytes,
    downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    createdAt: createdAt,
    completedAt: completedAt ?? this.completedAt,
    status: status ?? this.status,
    errorMessage: errorMessage ?? this.errorMessage,
    seriesId: seriesId,
    seasonNum: seasonNum,
    episodeNum: episodeNum,
    seriesName: seriesName,
    streamId: streamId,
  );

  static String encodeList(List<Download> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<Download> decodeList(String json) =>
      (jsonDecode(json) as List).map((e) => Download.fromJson(e)).toList();

  // Factory-Konstruktoren für einfache Erstellung
  factory Download.fromMovie({
    required int streamId,
    required String title,
    required String sourceUrl,
    String? imageUrl,
    String? extension,
  }) => Download(
    id: 'movie_$streamId',
    title: title,
    sourceUrl: sourceUrl,
    imageUrl: imageUrl,
    contentType: ContentType.movie,
    extension: extension ?? 'mp4',
    createdAt: DateTime.now(),
    streamId: streamId,
  );

  factory Download.fromSeriesEpisode({
    required int seriesId,
    required String seriesName,
    required int seasonNum,
    required int episodeNum,
    required String episodeTitle,
    required String sourceUrl,
    String? imageUrl,
    String? extension,
  }) => Download(
    id: 'series_${seriesId}_${seasonNum}_$episodeNum',
    title: episodeTitle,
    subtitle: 'S${seasonNum.toString().padLeft(2, '0')} E${episodeNum.toString().padLeft(2, '0')}',
    sourceUrl: sourceUrl,
    imageUrl: imageUrl,
    contentType: ContentType.series,
    extension: extension ?? 'mp4',
    createdAt: DateTime.now(),
    seriesId: seriesId,
    seasonNum: seasonNum,
    episodeNum: episodeNum,
    seriesName: seriesName,
  );
}
