import 'dart:convert';

enum ContentType { movie, series, live }

class WatchProgress {
  final String id; // Unique identifier (streamId or seriesId_seasonNum_episodeNum)
  final String title;
  final String? subtitle;
  final String streamUrl;
  final String? imageUrl;
  final ContentType contentType;
  final Duration position;
  final Duration duration;
  final DateTime lastWatched;

  // Für Serien
  final int? seriesId;
  final int? seasonNum;
  final int? episodeNum;

  WatchProgress({
    required this.id,
    required this.title,
    this.subtitle,
    required this.streamUrl,
    this.imageUrl,
    required this.contentType,
    required this.position,
    required this.duration,
    required this.lastWatched,
    this.seriesId,
    this.seasonNum,
    this.episodeNum,
  });

  double get progress => duration.inSeconds > 0
      ? (position.inSeconds / duration.inSeconds).clamp(0.0, 1.0)
      : 0.0;

  bool get isCompleted => progress > 0.9; // 90% als "fertig" betrachten

  String get formattedPosition {
    final hours = position.inHours;
    final minutes = position.inMinutes.remainder(60);
    final seconds = position.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get remainingTime {
    final remaining = duration - position;
    final minutes = remaining.inMinutes;
    if (minutes < 60) {
      return '$minutes Min. übrig';
    }
    final hours = remaining.inHours;
    final remainingMins = remaining.inMinutes.remainder(60);
    return '$hours Std. $remainingMins Min. übrig';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'streamUrl': streamUrl,
        'imageUrl': imageUrl,
        'contentType': contentType.index,
        'positionMs': position.inMilliseconds,
        'durationMs': duration.inMilliseconds,
        'lastWatched': lastWatched.toIso8601String(),
        'seriesId': seriesId,
        'seasonNum': seasonNum,
        'episodeNum': episodeNum,
      };

  factory WatchProgress.fromJson(Map<String, dynamic> json) => WatchProgress(
        id: json['id'],
        title: json['title'],
        subtitle: json['subtitle'],
        streamUrl: json['streamUrl'],
        imageUrl: json['imageUrl'],
        contentType: ContentType.values[json['contentType']],
        position: Duration(milliseconds: json['positionMs']),
        duration: Duration(milliseconds: json['durationMs']),
        lastWatched: DateTime.parse(json['lastWatched']),
        seriesId: json['seriesId'],
        seasonNum: json['seasonNum'],
        episodeNum: json['episodeNum'],
      );

  WatchProgress copyWith({
    Duration? position,
    Duration? duration,
    DateTime? lastWatched,
  }) =>
      WatchProgress(
        id: id,
        title: title,
        subtitle: subtitle,
        streamUrl: streamUrl,
        imageUrl: imageUrl,
        contentType: contentType,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        lastWatched: lastWatched ?? this.lastWatched,
        seriesId: seriesId,
        seasonNum: seasonNum,
        episodeNum: episodeNum,
      );

  static String encodeList(List<WatchProgress> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<WatchProgress> decodeList(String json) =>
      (jsonDecode(json) as List)
          .map((e) => WatchProgress.fromJson(e))
          .toList();
}
