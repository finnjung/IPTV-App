import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xtream_code_client/xtream_code_client.dart';
import 'cors_proxy_client.dart';
import '../models/watch_progress.dart';
import '../utils/content_parser.dart';

class XtreamCredentials {
  final String serverUrl;
  final String port;
  final String username;
  final String password;
  final String? corsProxy; // Optional CORS proxy for web

  XtreamCredentials({
    required this.serverUrl,
    required this.port,
    required this.username,
    required this.password,
    this.corsProxy,
  });

  bool get isValid =>
      serverUrl.isNotEmpty && username.isNotEmpty && password.isNotEmpty;
}

class XtreamService extends ChangeNotifier {
  static final XtreamService _instance = XtreamService._internal();
  factory XtreamService() => _instance;
  XtreamService._internal();

  XtreamCredentials? _credentials;
  bool _isConnected = false;
  bool _isLoading = false;
  String? _error;
  XTremeCodeGeneralInformation? _serverInfo;

  // Cached data
  List<XTremeCodeCategory>? _liveCategories;
  List<XTremeCodeCategory>? _vodCategories;
  List<XTremeCodeCategory>? _seriesCategories;

  final Map<String, List<XTremeCodeLiveStreamItem>> _liveStreamsByCategory = {};
  final Map<String, List<XTremeCodeVodItem>> _vodByCategory = {};
  final Map<String, List<XTremeCodeSeriesItem>> _seriesByCategory = {};

  // Leere Serien (ohne Episoden) - werden lazy beim Öffnen markiert
  Set<int> _emptySeriesIds = {};
  bool _autoHideEmptySeries = true;

  // Watch Progress - Fortschritt beim Schauen
  List<WatchProgress> _watchProgress = [];

  // Bevorzugte Sprache für Content
  String? _preferredLanguage;

  // Cached Start Screen Content
  StartScreenContent? _startScreenContent;
  bool _isLoadingStartScreen = false;

  bool get isConnected => _isConnected;
  bool get isStartScreenLoading => _isLoadingStartScreen;
  StartScreenContent? get startScreenContent => _startScreenContent;
  bool get autoHideEmptySeries => _autoHideEmptySeries;
  bool get isLoading => _isLoading;
  String? get preferredLanguage => _preferredLanguage;
  String? get error => _error;
  XtreamCredentials? get credentials => _credentials;
  XTremeCodeGeneralInformation? get serverInfo => _serverInfo;

  List<XTremeCodeCategory>? get liveCategories => _liveCategories;
  List<XTremeCodeCategory>? get vodCategories => _vodCategories;
  List<XTremeCodeCategory>? get seriesCategories => _seriesCategories;

  // Sortiert nach letztem Schauen, filtert abgeschlossene
  List<WatchProgress> get continueWatching => _watchProgress
      .where((p) => !p.isCompleted && p.position.inSeconds > 30)
      .toList()
    ..sort((a, b) => b.lastWatched.compareTo(a.lastWatched));

  XtreamCodeClient? get client {
    try {
      return XtreamCode.instance.client;
    } catch (e) {
      return null;
    }
  }

  Future<void> loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString('xtream_server_url');
    final port = prefs.getString('xtream_port');
    final username = prefs.getString('xtream_username');
    final password = prefs.getString('xtream_password');
    final corsProxy = prefs.getString('xtream_cors_proxy');

    // Leere Serien-IDs laden
    await _loadEmptySeriesIds();

    // Watch Progress laden
    await _loadWatchProgress();

    // Bevorzugte Sprache laden
    _preferredLanguage = prefs.getString('preferred_language');

    if (serverUrl != null && username != null && password != null) {
      _credentials = XtreamCredentials(
        serverUrl: serverUrl,
        port: port ?? '',
        username: username,
        password: password,
        corsProxy: corsProxy,
      );

      await connect(_credentials!, skipValidation: true);
    }
  }

  Future<void> saveCredentials(XtreamCredentials credentials) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('xtream_server_url', credentials.serverUrl);
    await prefs.setString('xtream_port', credentials.port);
    await prefs.setString('xtream_username', credentials.username);
    await prefs.setString('xtream_password', credentials.password);
    if (credentials.corsProxy != null) {
      await prefs.setString('xtream_cors_proxy', credentials.corsProxy!);
    } else {
      await prefs.remove('xtream_cors_proxy');
    }
    _credentials = credentials;
  }

  Future<bool> connect(XtreamCredentials credentials, {bool skipValidation = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Dispose previous instance if exists
      try {
        await XtreamCode.instance.dispose();
      } catch (_) {
        // Instance wasn't initialized yet, that's fine
      }

      // Parse URL - add protocol if missing
      String url = credentials.serverUrl.trim();
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'http://$url';
      }
      // Remove trailing slash
      if (url.endsWith('/')) {
        url = url.substring(0, url.length - 1);
      }

      // Parse the URL to extract components
      final uri = Uri.parse(url);

      // Use port from URL if present, otherwise from credentials, otherwise default 80
      String port = '80';
      if (uri.hasPort) {
        port = uri.port.toString();
      } else if (credentials.port.isNotEmpty) {
        port = credentials.port;
      }

      // Build clean URL without port (port is passed separately)
      url = '${uri.scheme}://${uri.host}';

      // Create HTTP client - use CORS proxy wrapper for web if specified
      http.Client? httpClient;
      if (credentials.corsProxy != null && credentials.corsProxy!.isNotEmpty) {
        httpClient = CorsProxyClient(credentials.corsProxy!.trim());
        debugPrint('Using CORS proxy: ${credentials.corsProxy}');
      }

      debugPrint('Connecting to: $url:$port');

      await XtreamCode.initialize(
        url: url,
        port: port,
        username: credentials.username,
        password: credentials.password,
        httpClient: httpClient,
      );

      // Test connection by fetching server info
      final info = await client?.serverInformation();

      if (info != null) {
        _serverInfo = info;
        _isConnected = true;
        await saveCredentials(credentials);

        // Load categories in background
        _loadCategories();

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        throw Exception('Keine Serverantwort erhalten');
      }
    } catch (e) {
      debugPrint('Connection error: $e');
      _error = 'Verbindung fehlgeschlagen: ${e.toString()}';
      _isConnected = false;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _loadCategories() async {
    try {
      _liveCategories = await client?.liveStreamCategories();
      _vodCategories = await client?.vodCategories();
      _seriesCategories = await client?.seriesCategories();

      debugPrint('Loaded ${_liveCategories?.length ?? 0} live categories');
      debugPrint('Loaded ${_vodCategories?.length ?? 0} VOD categories');
      debugPrint('Loaded ${_seriesCategories?.length ?? 0} series categories');

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  Future<List<XTremeCodeLiveStreamItem>> getLiveStreams(
      {XTremeCodeCategory? category}) async {
    if (!_isConnected || client == null) return [];

    final key = category?.categoryId?.toString() ?? 'all';

    if (_liveStreamsByCategory.containsKey(key)) {
      return _liveStreamsByCategory[key]!;
    }

    try {
      final streams = await client!.livestreamItems(category: category);
      _liveStreamsByCategory[key] = streams;
      return streams;
    } catch (e) {
      final cause = e is XTreamCodeClientException ? e.cause : e.toString();
      debugPrint('Error loading live streams: $cause');
      return [];
    }
  }

  Future<List<XTremeCodeVodItem>> getMovies(
      {XTremeCodeCategory? category}) async {
    if (!_isConnected || client == null) return [];

    final key = category?.categoryId?.toString() ?? 'all';

    if (_vodByCategory.containsKey(key)) {
      return _vodByCategory[key]!;
    }

    try {
      final movies = await client!.vodItems(category: category);
      _vodByCategory[key] = movies;
      return movies;
    } catch (e) {
      final cause = e is XTreamCodeClientException ? e.cause : e.toString();
      debugPrint('Error loading movies: $cause');
      return [];
    }
  }

  Future<List<XTremeCodeSeriesItem>> getSeries(
      {XTremeCodeCategory? category}) async {
    if (!_isConnected || client == null) return [];

    final key = category?.categoryId?.toString() ?? 'all';

    if (_seriesByCategory.containsKey(key)) {
      return _seriesByCategory[key]!;
    }

    try {
      final series = await client!.seriesItems(category: category);
      // Leere Serien ausfiltern (nur wenn aktiviert)
      final filteredSeries = _autoHideEmptySeries
          ? series.where((s) => !_emptySeriesIds.contains(s.seriesId)).toList()
          : series;
      _seriesByCategory[key] = filteredSeries;
      return filteredSeries;
    } catch (e) {
      final cause = e is XTreamCodeClientException ? e.cause : e.toString();
      debugPrint('Error loading series: $cause');
      return [];
    }
  }

  Future<XTremeCodeSeriesInfo?> getSeriesInfo(XTremeCodeSeriesItem series) async {
    if (!_isConnected || client == null) return null;

    try {
      return await client!.seriesInfo(series);
    } catch (e) {
      debugPrint('Error loading series info: $e');
      return null;
    }
  }

  Future<XTremeCodeVodInfo?> getMovieInfo(XTremeCodeVodItem movie) async {
    if (!_isConnected || client == null) return null;

    try {
      return await client!.vodInfo(movie);
    } catch (e) {
      debugPrint('Error loading movie info: $e');
      return null;
    }
  }

  String? getLiveStreamUrl(XTremeCodeLiveStreamItem stream) {
    if (client == null) return null;
    try {
      return client!.streamUrl(stream.streamId ?? 0, ['ts', 'm3u8']);
    } catch (e) {
      debugPrint('Error getting stream URL: $e');
      return null;
    }
  }

  String? getMovieUrl(int streamId, {String container = 'mp4'}) {
    if (client == null) return null;
    try {
      return client!.movieUrl(streamId, container);
    } catch (e) {
      debugPrint('Error getting movie URL: $e');
      return null;
    }
  }

  String? getSeriesEpisodeUrl(int episodeId, {String container = 'mp4'}) {
    if (client == null) return null;
    try {
      return client!.seriesUrl(episodeId, container);
    } catch (e) {
      debugPrint('Error getting episode URL: $e');
      return null;
    }
  }

  Future<void> disconnect() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('xtream_server_url');
    await prefs.remove('xtream_port');
    await prefs.remove('xtream_username');
    await prefs.remove('xtream_password');

    _credentials = null;
    _isConnected = false;
    _serverInfo = null;
    _liveCategories = null;
    _vodCategories = null;
    _seriesCategories = null;
    _liveStreamsByCategory.clear();
    _vodByCategory.clear();
    _seriesByCategory.clear();
    _startScreenContent = null;

    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Lädt die gespeicherten leeren Serien-IDs und Einstellungen
  Future<void> _loadEmptySeriesIds() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList('empty_series_ids') ?? [];
    _emptySeriesIds = ids.map((id) => int.tryParse(id) ?? 0).toSet();
    _autoHideEmptySeries = prefs.getBool('auto_hide_empty_series') ?? true;
    debugPrint('Loaded ${_emptySeriesIds.length} empty series IDs, autoHide: $_autoHideEmptySeries');
  }

  /// Aktiviert/Deaktiviert das automatische Ausblenden leerer Serien
  Future<void> setAutoHideEmptySeries(bool value) async {
    _autoHideEmptySeries = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_hide_empty_series', value);

    // Cache leeren damit Listen neu geladen werden
    _seriesByCategory.clear();
    notifyListeners();

    debugPrint('Auto-hide empty series: $value');
  }

  /// Speichert die leeren Serien-IDs
  Future<void> _saveEmptySeriesIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'empty_series_ids',
      _emptySeriesIds.map((id) => id.toString()).toList(),
    );
  }

  /// Markiert eine Serie als leer (lazy validation)
  Future<void> markSeriesAsEmpty(int seriesId) async {
    // Nur markieren wenn Auto-Hide aktiviert ist
    if (!_autoHideEmptySeries) return;

    if (!_emptySeriesIds.contains(seriesId)) {
      _emptySeriesIds.add(seriesId);
      await _saveEmptySeriesIds();

      // Cache leeren damit die Serie aus Listen verschwindet
      _seriesByCategory.clear();
      notifyListeners();

      debugPrint('Marked series $seriesId as empty. Total: ${_emptySeriesIds.length}');
    }
  }

  /// Löscht alle gespeicherten leeren Serien-IDs (Reset)
  Future<void> clearEmptySeriesIds() async {
    _emptySeriesIds.clear();
    _seriesByCategory.clear();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('empty_series_ids');

    notifyListeners();
    debugPrint('Cleared all empty series IDs');
  }

  /// Prüft ob eine Serie leer ist
  bool isSeriesEmpty(XTremeCodeSeriesItem series) {
    return _emptySeriesIds.contains(series.seriesId);
  }

  /// Gibt die Anzahl der als leer markierten Serien zurück
  int get emptySeriesCount => _emptySeriesIds.length;

  // ==================== Watch Progress ====================

  /// Lädt den gespeicherten Watch-Progress
  Future<void> _loadWatchProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('watch_progress');
      if (json != null) {
        _watchProgress = WatchProgress.decodeList(json);
        debugPrint('Loaded ${_watchProgress.length} watch progress entries');
      }
    } catch (e) {
      debugPrint('Error loading watch progress: $e');
      _watchProgress = [];
    }
  }

  /// Speichert den Watch-Progress
  Future<void> _saveWatchProgress() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('watch_progress', WatchProgress.encodeList(_watchProgress));
    } catch (e) {
      debugPrint('Error saving watch progress: $e');
    }
  }

  /// Aktualisiert oder erstellt einen Watch-Progress-Eintrag
  Future<void> updateWatchProgress(WatchProgress progress) async {
    final index = _watchProgress.indexWhere((p) => p.id == progress.id);

    if (index >= 0) {
      _watchProgress[index] = progress;
    } else {
      _watchProgress.add(progress);
    }

    await _saveWatchProgress();
    notifyListeners();
  }

  /// Holt den Watch-Progress für eine bestimmte ID
  WatchProgress? getWatchProgress(String id) {
    try {
      return _watchProgress.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Entfernt einen Watch-Progress-Eintrag
  Future<void> removeWatchProgress(String id) async {
    _watchProgress.removeWhere((p) => p.id == id);
    await _saveWatchProgress();
    notifyListeners();
  }

  /// Löscht alle Watch-Progress-Einträge
  Future<void> clearAllWatchProgress() async {
    _watchProgress.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('watch_progress');
    notifyListeners();
  }

  // ==================== Spracheinstellungen ====================

  /// Setzt die bevorzugte Sprache für Inhalte
  Future<void> setPreferredLanguage(String? language) async {
    _preferredLanguage = language;
    final prefs = await SharedPreferences.getInstance();

    if (language != null) {
      await prefs.setString('preferred_language', language);
    } else {
      await prefs.remove('preferred_language');
    }

    // Cache invalidieren wenn Sprache geändert wird
    _startScreenContent = null;

    notifyListeners();
    debugPrint('Preferred language set to: $language');
  }

  // ==================== Start Screen Content ====================

  /// Lädt den Content für die Startseite (gecacht)
  Future<StartScreenContent> loadStartScreenContent({bool forceRefresh = false}) async {
    // Return cached content if available
    if (_startScreenContent != null && !forceRefresh) {
      return _startScreenContent!;
    }

    // Prevent multiple simultaneous loads
    if (_isLoadingStartScreen) {
      // Wait for current load to finish
      while (_isLoadingStartScreen) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _startScreenContent ?? StartScreenContent.empty();
    }

    _isLoadingStartScreen = true;
    notifyListeners();

    try {
      // Load all content
      final allMovies = await getMovies();
      final allSeries = await getSeries();

      // Find popular content (HOT, TOP, etc.) using compute for heavy parsing
      final popularMovies = await compute(_filterPopularMovies, allMovies);
      final popularSeries = await compute(_filterPopularSeries, allSeries);

      // Get recommendations based on language preference
      List<XTremeCodeVodItem> recommendedMovies;
      List<XTremeCodeSeriesItem> recommendedSeries;

      if (_preferredLanguage != null) {
        recommendedMovies = await compute(
          _sortMoviesByLanguage,
          _SortParams(allMovies, _preferredLanguage!),
        );
        recommendedSeries = await compute(
          _sortSeriesByLanguage,
          _SortParams(allSeries, _preferredLanguage!),
        );
      } else {
        // Random selection without language preference
        recommendedMovies = List<XTremeCodeVodItem>.from(allMovies)..shuffle();
        recommendedSeries = List<XTremeCodeSeriesItem>.from(allSeries)..shuffle();
      }

      _startScreenContent = StartScreenContent(
        popularMovies: popularMovies.take(20).toList(),
        popularSeries: popularSeries.take(20).toList(),
        recommendedMovies: recommendedMovies.take(20).toList(),
        recommendedSeries: recommendedSeries.take(20).toList(),
        preferredLanguage: _preferredLanguage,
      );

      debugPrint('Start screen content loaded: ${popularMovies.length} popular movies, ${popularSeries.length} popular series');
    } catch (e) {
      debugPrint('Error loading start screen content: $e');
      _startScreenContent = StartScreenContent.empty();
    }

    _isLoadingStartScreen = false;
    notifyListeners();

    return _startScreenContent!;
  }

  /// Invalidiert den Start Screen Cache
  void invalidateStartScreenCache() {
    _startScreenContent = null;
    notifyListeners();
  }

  /// Sucht nach Filmen, Serien und Live TV
  /// Gibt gefilterte Listen zurück basierend auf dem Suchbegriff
  Future<SearchResults> search(String query) async {
    if (!_isConnected || client == null || query.length < 2) {
      return SearchResults.empty();
    }

    final lowerQuery = query.toLowerCase();

    // Alle Daten laden falls nicht gecacht
    final allMovies = await getMovies();
    final allSeries = await getSeries();
    final allLiveStreams = await getLiveStreams();

    // Filtern nach Suchbegriff
    final movies = allMovies
        .where((m) => (m.name ?? '').toLowerCase().contains(lowerQuery))
        .toList();

    final series = allSeries
        .where((s) =>
            (s.name ?? '').toLowerCase().contains(lowerQuery) &&
            (!_autoHideEmptySeries || !_emptySeriesIds.contains(s.seriesId)))
        .toList();

    final liveStreams = allLiveStreams
        .where((l) => (l.name ?? '').toLowerCase().contains(lowerQuery))
        .toList();

    return SearchResults(
      movies: movies,
      series: series,
      liveStreams: liveStreams,
    );
  }
}

class SearchResults {
  final List<XTremeCodeVodItem> movies;
  final List<XTremeCodeSeriesItem> series;
  final List<XTremeCodeLiveStreamItem> liveStreams;

  SearchResults({
    required this.movies,
    required this.series,
    required this.liveStreams,
  });

  factory SearchResults.empty() => SearchResults(
        movies: [],
        series: [],
        liveStreams: [],
      );

  bool get isEmpty => movies.isEmpty && series.isEmpty && liveStreams.isEmpty;
  int get totalCount => movies.length + series.length + liveStreams.length;
}

// ==================== Start Screen Content ====================

class StartScreenContent {
  final List<XTremeCodeVodItem> popularMovies;
  final List<XTremeCodeSeriesItem> popularSeries;
  final List<XTremeCodeVodItem> recommendedMovies;
  final List<XTremeCodeSeriesItem> recommendedSeries;
  final String? preferredLanguage;

  StartScreenContent({
    required this.popularMovies,
    required this.popularSeries,
    required this.recommendedMovies,
    required this.recommendedSeries,
    this.preferredLanguage,
  });

  factory StartScreenContent.empty() => StartScreenContent(
        popularMovies: [],
        popularSeries: [],
        recommendedMovies: [],
        recommendedSeries: [],
      );

  bool get isEmpty =>
      popularMovies.isEmpty &&
      popularSeries.isEmpty &&
      recommendedMovies.isEmpty &&
      recommendedSeries.isEmpty;
}

// Helper class for isolate parameters
class _SortParams<T> {
  final List<T> items;
  final String language;

  _SortParams(this.items, this.language);
}

// Isolate functions for heavy parsing (must be top-level)
List<XTremeCodeVodItem> _filterPopularMovies(List<XTremeCodeVodItem> movies) {
  return movies.where((m) {
    final metadata = ContentParser.parse(m.name ?? '');
    return metadata.isPopular;
  }).toList();
}

List<XTremeCodeSeriesItem> _filterPopularSeries(List<XTremeCodeSeriesItem> series) {
  return series.where((s) {
    final metadata = ContentParser.parse(s.name ?? '');
    return metadata.isPopular;
  }).toList();
}

List<XTremeCodeVodItem> _sortMoviesByLanguage(_SortParams<XTremeCodeVodItem> params) {
  return ContentParser.sortByPreference<XTremeCodeVodItem>(
    params.items,
    params.language,
    (m) => m.name ?? '',
  );
}

List<XTremeCodeSeriesItem> _sortSeriesByLanguage(_SortParams<XTremeCodeSeriesItem> params) {
  return ContentParser.sortByPreference<XTremeCodeSeriesItem>(
    params.items,
    params.language,
    (s) => s.name ?? '',
  );
}
