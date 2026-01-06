import 'dart:convert';
import 'watch_progress.dart'; // Für ContentType enum

class Favorite {
  final String id; // Unique: movie_streamId, series_seriesId, live_streamId
  final String title;
  final String? imageUrl;
  final ContentType contentType;
  final DateTime addedAt;

  // Zusätzliche Daten für Navigation
  final int? streamId; // Für Filme/Live
  final int? seriesId; // Für Serien
  final String? extension; // Container-Extension für Filme (mp4, mkv, etc.)

  Favorite({
    required this.id,
    required this.title,
    this.imageUrl,
    required this.contentType,
    required this.addedAt,
    this.streamId,
    this.seriesId,
    this.extension,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'imageUrl': imageUrl,
        'contentType': contentType.index,
        'addedAt': addedAt.toIso8601String(),
        'streamId': streamId,
        'seriesId': seriesId,
        'extension': extension,
      };

  factory Favorite.fromJson(Map<String, dynamic> json) => Favorite(
        id: json['id'],
        title: json['title'],
        imageUrl: json['imageUrl'],
        contentType: ContentType.values[json['contentType']],
        addedAt: DateTime.parse(json['addedAt']),
        streamId: json['streamId'],
        seriesId: json['seriesId'],
        extension: json['extension'],
      );

  static String encodeList(List<Favorite> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<Favorite> decodeList(String json) =>
      (jsonDecode(json) as List).map((e) => Favorite.fromJson(e)).toList();

  // Factory-Konstruktoren für einfache Erstellung
  factory Favorite.fromMovie({
    required int streamId,
    required String title,
    String? imageUrl,
    String? extension,
  }) =>
      Favorite(
        id: 'movie_$streamId',
        title: title,
        imageUrl: imageUrl,
        contentType: ContentType.movie,
        addedAt: DateTime.now(),
        streamId: streamId,
        extension: extension,
      );

  factory Favorite.fromSeries({
    required int seriesId,
    required String title,
    String? imageUrl,
  }) =>
      Favorite(
        id: 'series_$seriesId',
        title: title,
        imageUrl: imageUrl,
        contentType: ContentType.series,
        addedAt: DateTime.now(),
        seriesId: seriesId,
      );

  factory Favorite.fromLiveStream({
    required int streamId,
    required String title,
    String? imageUrl,
  }) =>
      Favorite(
        id: 'live_$streamId',
        title: title,
        imageUrl: imageUrl,
        contentType: ContentType.live,
        addedAt: DateTime.now(),
        streamId: streamId,
      );
}
