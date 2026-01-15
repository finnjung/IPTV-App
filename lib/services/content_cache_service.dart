import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:xtream_code_client/xtream_code_client.dart';
import 'xtream_service.dart';
import '../data/curated_content.dart';

/// Service für persistentes Caching von Screen-Inhalten
class ContentCacheService {
  static final ContentCacheService _instance = ContentCacheService._internal();
  factory ContentCacheService() => _instance;
  ContentCacheService._internal();

  Directory? _cacheDir;
  static const String _cacheVersion = '2'; // v2: allMoviesSorted & allSeriesSorted werden jetzt gecacht

  /// Initialisiert das Cache-Verzeichnis
  Future<void> init() async {
    if (_cacheDir != null) return;

    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = Directory('${appDir.path}/content_cache');

    if (!await _cacheDir!.exists()) {
      await _cacheDir!.create(recursive: true);
    }
  }

  /// Generiert einen Hash der Credentials für Cache-Invalidierung
  String _hashCredentials(XtreamCredentials credentials) {
    final data = '${credentials.serverUrl}:${credentials.port}:${credentials.username}:${credentials.password}';
    // Simple hash - Dart's built-in hashCode
    return data.hashCode.toRadixString(16);
  }

  /// Prüft ob der Cache gültig ist
  Future<bool> isCacheValid(XtreamCredentials credentials) async {
    await init();

    try {
      final metaFile = File('${_cacheDir!.path}/cache_meta.json');
      if (!await metaFile.exists()) return false;

      final metaJson = jsonDecode(await metaFile.readAsString());
      final cachedHash = metaJson['credentials_hash'] as String?;
      final cachedVersion = metaJson['version'] as String?;

      if (cachedVersion != _cacheVersion) return false;
      if (cachedHash != _hashCredentials(credentials)) return false;

      // Prüfe ob alle Cache-Dateien existieren
      final files = ['start_screen.json', 'movies_screen.json', 'series_screen.json', 'live_tv_screen.json'];
      for (final file in files) {
        if (!await File('${_cacheDir!.path}/$file').exists()) return false;
      }

      return true;
    } catch (e) {
      debugPrint('Cache validation error: $e');
      return false;
    }
  }

  /// Speichert die Cache-Metadaten
  Future<void> _saveMeta(XtreamCredentials credentials) async {
    final metaFile = File('${_cacheDir!.path}/cache_meta.json');
    await metaFile.writeAsString(jsonEncode({
      'credentials_hash': _hashCredentials(credentials),
      'version': _cacheVersion,
      'timestamp': DateTime.now().toIso8601String(),
    }));
  }

  /// Speichert den StartScreen-Content
  Future<void> saveStartScreenContent(StartScreenContent content, XtreamCredentials credentials) async {
    await init();

    try {
      final file = File('${_cacheDir!.path}/start_screen.json');
      final json = _startScreenContentToJson(content);
      // Speichere auch das Datum für tägliche Invalidierung des Spotlights
      json['cached_date'] = DateTime.now().toIso8601String().substring(0, 10); // YYYY-MM-DD
      await file.writeAsString(jsonEncode(json));
      await _saveMeta(credentials);
      debugPrint('StartScreen content cached for ${json['cached_date']}');
    } catch (e) {
      debugPrint('Error caching start screen: $e');
    }
  }

  /// Lädt den StartScreen-Content aus dem Cache
  Future<StartScreenContent?> loadStartScreenContent() async {
    await init();

    try {
      final file = File('${_cacheDir!.path}/start_screen.json');
      if (!await file.exists()) return null;

      final json = jsonDecode(await file.readAsString());
      return _startScreenContentFromJson(json);
    } catch (e) {
      debugPrint('Error loading start screen cache: $e');
      return null;
    }
  }

  /// Speichert den MoviesScreen-Content
  Future<void> saveMoviesScreenContent(MoviesScreenContent content, XtreamCredentials credentials) async {
    await init();

    try {
      final file = File('${_cacheDir!.path}/movies_screen.json');
      final json = _moviesScreenContentToJson(content);
      await file.writeAsString(jsonEncode(json));
      await _saveMeta(credentials);
      debugPrint('MoviesScreen content cached');
    } catch (e) {
      debugPrint('Error caching movies screen: $e');
    }
  }

  /// Lädt den MoviesScreen-Content aus dem Cache
  Future<MoviesScreenContent?> loadMoviesScreenContent() async {
    await init();

    try {
      final file = File('${_cacheDir!.path}/movies_screen.json');
      if (!await file.exists()) {
        debugPrint('Cache file not found: movies_screen.json');
        return null;
      }

      final content = await file.readAsString();
      debugPrint('Movies cache file size: ${content.length} bytes');
      final json = jsonDecode(content);
      final result = _moviesScreenContentFromJson(json);
      debugPrint('Movies cache parsed: ${result.categories.length} categories');
      return result;
    } catch (e) {
      debugPrint('Error loading movies screen cache: $e');
      return null;
    }
  }

  /// Speichert den SeriesScreen-Content
  Future<void> saveSeriesScreenContent(SeriesScreenContent content, XtreamCredentials credentials) async {
    await init();

    try {
      final file = File('${_cacheDir!.path}/series_screen.json');
      final json = _seriesScreenContentToJson(content);
      await file.writeAsString(jsonEncode(json));
      await _saveMeta(credentials);
      debugPrint('SeriesScreen content cached');
    } catch (e) {
      debugPrint('Error caching series screen: $e');
    }
  }

  /// Lädt den SeriesScreen-Content aus dem Cache
  Future<SeriesScreenContent?> loadSeriesScreenContent() async {
    await init();

    try {
      final file = File('${_cacheDir!.path}/series_screen.json');
      if (!await file.exists()) return null;

      final json = jsonDecode(await file.readAsString());
      return _seriesScreenContentFromJson(json);
    } catch (e) {
      debugPrint('Error loading series screen cache: $e');
      return null;
    }
  }

  /// Speichert den LiveTvScreen-Content
  Future<void> saveLiveTvScreenContent(LiveTvScreenContent content, XtreamCredentials credentials) async {
    await init();

    try {
      final file = File('${_cacheDir!.path}/live_tv_screen.json');
      final json = _liveTvScreenContentToJson(content);
      await file.writeAsString(jsonEncode(json));
      await _saveMeta(credentials);
      debugPrint('LiveTvScreen content cached');
    } catch (e) {
      debugPrint('Error caching live tv screen: $e');
    }
  }

  /// Lädt den LiveTvScreen-Content aus dem Cache
  Future<LiveTvScreenContent?> loadLiveTvScreenContent() async {
    await init();

    try {
      final file = File('${_cacheDir!.path}/live_tv_screen.json');
      if (!await file.exists()) return null;

      final json = jsonDecode(await file.readAsString());
      return _liveTvScreenContentFromJson(json);
    } catch (e) {
      debugPrint('Error loading live tv screen cache: $e');
      return null;
    }
  }

  /// Löscht den gesamten Cache
  Future<void> clearCache() async {
    await init();

    try {
      if (await _cacheDir!.exists()) {
        await _cacheDir!.delete(recursive: true);
        await _cacheDir!.create(recursive: true);
      }
      debugPrint('Cache cleared');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }

  // ==================== JSON Serialization ====================

  Map<String, dynamic> _startScreenContentToJson(StartScreenContent content) {
    return {
      'popularMovies': content.popularMovies.map((m) => m.toJson()).toList(),
      'popularSeries': content.popularSeries.map((s) => s.toJson()).toList(),
      'spotlight': content.spotlight != null ? _spotlightToJson(content.spotlight!) : null,
      'curatedMovies': content.curatedMovies.map((m) => m.toJson()).toList(),
      'curatedSeries': content.curatedSeries.map((s) => s.toJson()).toList(),
      'curatedKids': content.curatedKids.map((item) {
        if (item is XTremeCodeVodItem) {
          return {'type': 'movie', 'data': item.toJson()};
        } else if (item is XTremeCodeSeriesItem) {
          return {'type': 'series', 'data': item.toJson()};
        }
        return null;
      }).where((e) => e != null).toList(),
      'thrillerSeries': content.thrillerSeries.map((s) => s.toJson()).toList(),
      'actionMovies': content.actionMovies.map((m) => m.toJson()).toList(),
      // Hinweis: allMovies und allSeries werden NICHT gecacht - zu groß
      // Diese werden bei Bedarf über API geladen
      'sectionOrder': content.sectionOrder.map((s) => s.name).toList(),
    };
  }

  StartScreenContent _startScreenContentFromJson(Map<String, dynamic> json) {
    final curatedKids = <dynamic>[];
    for (final item in (json['curatedKids'] as List? ?? [])) {
      if (item['type'] == 'movie') {
        curatedKids.add(XTremeCodeVodItem.fromJson(item['data']));
      } else if (item['type'] == 'series') {
        curatedKids.add(XTremeCodeSeriesItem.fromJson(item['data']));
      }
    }

    return StartScreenContent(
      popularMovies: (json['popularMovies'] as List? ?? [])
          .map((m) => XTremeCodeVodItem.fromJson(m))
          .toList(),
      popularSeries: (json['popularSeries'] as List? ?? [])
          .map((s) => XTremeCodeSeriesItem.fromJson(s))
          .toList(),
      spotlight: json['spotlight'] != null ? _spotlightFromJson(json['spotlight']) : null,
      curatedMovies: (json['curatedMovies'] as List? ?? [])
          .map((m) => XTremeCodeVodItem.fromJson(m))
          .toList(),
      curatedSeries: (json['curatedSeries'] as List? ?? [])
          .map((s) => XTremeCodeSeriesItem.fromJson(s))
          .toList(),
      curatedKids: curatedKids,
      thrillerSeries: (json['thrillerSeries'] as List? ?? [])
          .map((s) => XTremeCodeSeriesItem.fromJson(s))
          .toList(),
      actionMovies: (json['actionMovies'] as List? ?? [])
          .map((m) => XTremeCodeVodItem.fromJson(m))
          .toList(),
      allMovies: [], // Wird bei Bedarf über API geladen
      allSeries: [], // Wird bei Bedarf über API geladen
      sectionOrder: (json['sectionOrder'] as List? ?? [])
          .map((s) => StartScreenSection.values.firstWhere(
                (e) => e.name == s,
                orElse: () => StartScreenSection.curatedPopular,
              ))
          .toList(),
    );
  }

  Map<String, dynamic> _spotlightToJson(SpotlightContent spotlight) {
    Map<String, dynamic>? originalItemJson;
    String? originalItemType;

    if (spotlight.originalItem is XTremeCodeVodItem) {
      originalItemJson = (spotlight.originalItem as XTremeCodeVodItem).toJson();
      originalItemType = 'movie';
    } else if (spotlight.originalItem is XTremeCodeSeriesItem) {
      originalItemJson = (spotlight.originalItem as XTremeCodeSeriesItem).toJson();
      originalItemType = 'series';
    }

    return {
      'name': spotlight.name,
      'imageUrl': spotlight.imageUrl,
      'quality': spotlight.quality,
      'language': spotlight.language,
      'curatedTitle': {
        'name': spotlight.curatedTitle.name,
        'category': spotlight.curatedTitle.category.name,
      },
      'isMovie': spotlight.isMovie,
      'originalItemType': originalItemType,
      'originalItem': originalItemJson,
    };
  }

  SpotlightContent _spotlightFromJson(Map<String, dynamic> json) {
    dynamic originalItem;
    if (json['originalItemType'] == 'movie' && json['originalItem'] != null) {
      originalItem = XTremeCodeVodItem.fromJson(json['originalItem']);
    } else if (json['originalItemType'] == 'series' && json['originalItem'] != null) {
      originalItem = XTremeCodeSeriesItem.fromJson(json['originalItem']);
    }

    final categoryName = json['curatedTitle']['category'] as String;
    final category = CuratedCategory.values.firstWhere(
      (c) => c.name == categoryName,
      orElse: () => CuratedCategory.movie,
    );

    return SpotlightContent(
      name: json['name'] ?? '',
      imageUrl: json['imageUrl'],
      quality: json['quality'],
      language: json['language'],
      curatedTitle: CuratedTitle(json['curatedTitle']['name'] ?? '', category),
      isMovie: json['isMovie'] ?? true,
      originalItem: originalItem,
    );
  }

  Map<String, dynamic> _moviesScreenContentToJson(MoviesScreenContent content) {
    return {
      'categories': content.categories.map((c) => {
        'title': c.title,
        'icon': c.icon,
        'items': c.items.map((m) => m.toJson()).toList(),
      }).toList(),
      'allMoviesSorted': content.allMoviesSorted.map((m) => m.toJson()).toList(),
    };
  }

  MoviesScreenContent _moviesScreenContentFromJson(Map<String, dynamic> json) {
    return MoviesScreenContent(
      categories: (json['categories'] as List? ?? []).map((c) => PseudoCategory<XTremeCodeVodItem>(
        title: c['title'] ?? '',
        icon: c['icon'] ?? '',
        items: (c['items'] as List? ?? [])
            .map((m) => XTremeCodeVodItem.fromJson(m))
            .toList(),
      )).toList(),
      allMoviesSorted: (json['allMoviesSorted'] as List? ?? [])
          .map((m) => XTremeCodeVodItem.fromJson(m))
          .toList(),
    );
  }

  Map<String, dynamic> _seriesScreenContentToJson(SeriesScreenContent content) {
    return {
      'categories': content.categories.map((c) => {
        'title': c.title,
        'icon': c.icon,
        'items': c.items.map((s) => s.toJson()).toList(),
      }).toList(),
      'allSeriesSorted': content.allSeriesSorted.map((s) => s.toJson()).toList(),
    };
  }

  SeriesScreenContent _seriesScreenContentFromJson(Map<String, dynamic> json) {
    return SeriesScreenContent(
      categories: (json['categories'] as List? ?? []).map((c) => PseudoCategory<XTremeCodeSeriesItem>(
        title: c['title'] ?? '',
        icon: c['icon'] ?? '',
        items: (c['items'] as List? ?? [])
            .map((s) => XTremeCodeSeriesItem.fromJson(s))
            .toList(),
      )).toList(),
      allSeriesSorted: (json['allSeriesSorted'] as List? ?? [])
          .map((s) => XTremeCodeSeriesItem.fromJson(s))
          .toList(),
    );
  }

  Map<String, dynamic> _liveTvScreenContentToJson(LiveTvScreenContent content) {
    return {
      'categories': content.categories.map((c) => {
        'title': c.title,
        'icon': c.icon,
        'items': c.items.map((s) => s.toJson()).toList(),
      }).toList(),
      // allStreamsSorted wird NICHT gecacht
    };
  }

  LiveTvScreenContent _liveTvScreenContentFromJson(Map<String, dynamic> json) {
    return LiveTvScreenContent(
      categories: (json['categories'] as List? ?? []).map((c) => PseudoCategory<XTremeCodeLiveStreamItem>(
        title: c['title'] ?? '',
        icon: c['icon'] ?? '',
        items: (c['items'] as List? ?? [])
            .map((s) => XTremeCodeLiveStreamItem.fromJson(s))
            .toList(),
      )).toList(),
      allStreamsSorted: [], // Wird bei Bedarf über API geladen
    );
  }
}
