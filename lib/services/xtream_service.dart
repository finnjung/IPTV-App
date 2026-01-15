import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xtream_code_client/xtream_code_client.dart';
import 'cors_proxy_client.dart';
import 'content_cache_service.dart';
import '../models/watch_progress.dart';
import '../models/favorite.dart';
import '../utils/content_parser.dart';
import '../data/curated_content.dart';

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

  // Favoriten
  List<Favorite> _favorites = [];

  // Bevorzugte Sprache für Content
  String? _preferredLanguage;

  // Player Buffer Mode: 'live', 'balanced', 'stable'
  String _bufferMode = 'balanced';

  // Suchhistorie - letzte Suchanfragen
  List<String> _searchHistory = [];

  // Cached Start Screen Content
  StartScreenContent? _startScreenContent;
  bool _isLoadingStartScreen = false;

  // Cached Screen Content for Movies/Series/Live TV
  MoviesScreenContent? _moviesScreenContent;
  SeriesScreenContent? _seriesScreenContent;
  LiveTvScreenContent? _liveTvScreenContent;
  bool _isLoadingMovies = false;
  bool _isLoadingSeries = false;
  bool _isLoadingLiveTv = false;

  // Preloading State
  bool _isPreloading = false;
  double _preloadProgress = 0.0;
  String _preloadStatus = '';
  final ContentCacheService _cacheService = ContentCacheService();

  bool get isConnected => _isConnected;
  bool get isStartScreenLoading => _isLoadingStartScreen;
  StartScreenContent? get startScreenContent => _startScreenContent;
  MoviesScreenContent? get moviesScreenContent => _moviesScreenContent;
  SeriesScreenContent? get seriesScreenContent => _seriesScreenContent;
  LiveTvScreenContent? get liveTvScreenContent => _liveTvScreenContent;
  bool get isLoadingMovies => _isLoadingMovies;
  bool get isLoadingSeries => _isLoadingSeries;
  bool get isLoadingLiveTv => _isLoadingLiveTv;
  bool get autoHideEmptySeries => _autoHideEmptySeries;
  bool get isLoading => _isLoading;
  String? get preferredLanguage => _preferredLanguage;
  String get bufferMode => _bufferMode;
  List<String> get searchHistory => List.unmodifiable(_searchHistory);
  String? get error => _error;
  XtreamCredentials? get credentials => _credentials;
  XTremeCodeGeneralInformation? get serverInfo => _serverInfo;

  // Preloading Getters
  bool get isPreloading => _isPreloading;
  double get preloadProgress => _preloadProgress;
  String get preloadStatus => _preloadStatus;

  List<XTremeCodeCategory>? get liveCategories => _liveCategories;
  List<XTremeCodeCategory>? get vodCategories => _vodCategories;
  List<XTremeCodeCategory>? get seriesCategories => _seriesCategories;

  // Sortiert nach letztem Schauen, filtert abgeschlossene und kaum geschaute
  List<WatchProgress> get continueWatching => _watchProgress
      .where((p) {
        // Nicht anzeigen wenn >= 90% geschaut (ist completed)
        if (p.isCompleted) return false;

        // Minimum: 2 Minuten ODER 5% geschaut (das höhere von beiden)
        final minSeconds = 120; // 2 Minuten
        final minProgress = 0.05; // 5%
        final hasWatchedEnough = p.position.inSeconds >= minSeconds || p.progress >= minProgress;

        return hasWatchedEnough;
      })
      .toList()
    ..sort((a, b) => b.lastWatched.compareTo(a.lastWatched));

  // Sortiert nach Hinzufüge-Zeitpunkt (neueste zuerst)
  List<Favorite> get favorites => List<Favorite>.from(_favorites)
    ..sort((a, b) => b.addedAt.compareTo(a.addedAt));

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

    // Favoriten laden
    await _loadFavorites();

    // Suchhistorie laden
    await _loadSearchHistory();

    // Bevorzugte Sprache laden
    _preferredLanguage = prefs.getString('preferred_language');

    // Buffer Mode laden
    _bufferMode = prefs.getString('player_buffer_mode') ?? 'balanced';

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

        // Start preloading all content
        // Setze _isPreloading SYNCHRON, damit Screens darauf warten
        _isPreloading = true;
        _preloadProgress = 0.0;
        _preloadStatus = 'Starte...';

        _isLoading = false;
        notifyListeners();

        // Jetzt async preloaden (Screens warten auf _isPreloading)
        preloadAllContent();

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

  /// Gets series info directly by seriesId (for favorites navigation)
  Future<XTremeCodeSeriesInfo?> getSeriesInfoById(int seriesId) async {
    if (!_isConnected || client == null) return null;

    try {
      // The xtream_code_client only uses seriesId from the item,
      // so we can fetch by making a direct HTTP request
      final baseUrl = client!.baseUrl;
      final response = await http.get(
        Uri.parse('$baseUrl&action=get_series_info&series_id=$seriesId'),
      );
      if (response.statusCode == 200) {
        final parsed = jsonDecode(response.body) as Map<String, dynamic>;
        return XTremeCodeSeriesInfo.fromJson(parsed);
      }
      return null;
    } catch (e) {
      debugPrint('Error loading series info by ID: $e');
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
      return _cleanUrl(client!.streamUrl(stream.streamId ?? 0, ['ts', 'm3u8']));
    } catch (e) {
      debugPrint('Error getting stream URL: $e');
      return null;
    }
  }

  /// Bereinigt URLs von trailing Punkten und Leerzeichen
  String _cleanUrl(String url) {
    String clean = url;
    while (clean.endsWith('.') || clean.endsWith(' ')) {
      clean = clean.substring(0, clean.length - 1);
    }
    return clean;
  }

  String? getMovieUrl(int streamId, {String container = 'mp4'}) {
    if (client == null) return null;
    try {
      // Container bereinigen (Punkte, Leerzeichen entfernen - manche APIs liefern ".mp4" statt "mp4")
      String cleanContainer = container.replaceAll('.', '').replaceAll(' ', '').trim();
      if (cleanContainer.isEmpty) cleanContainer = 'mp4';

      final url = _cleanUrl(client!.movieUrl(streamId, cleanContainer));
      debugPrint('Movie URL: $url (container: "$container" -> "$cleanContainer")');
      return url;
    } catch (e) {
      debugPrint('Error getting movie URL: $e');
      return null;
    }
  }

  String? getSeriesEpisodeUrl(int episodeId, {String container = 'mp4'}) {
    if (client == null) return null;
    try {
      // Container bereinigen (Punkte, Leerzeichen entfernen)
      String cleanContainer = container.replaceAll('.', '').replaceAll(' ', '').trim();
      if (cleanContainer.isEmpty) cleanContainer = 'mp4';

      final url = _cleanUrl(client!.seriesUrl(episodeId, cleanContainer));
      debugPrint('Episode URL: $url (container: "$container" -> "$cleanContainer")');
      return url;
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
    _moviesScreenContent = null;
    _seriesScreenContent = null;
    _liveTvScreenContent = null;

    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ==================== Content Preloading ====================

  /// Lädt alle Vorschläge/kuratierten Inhalte vor und cached sie
  Future<void> preloadAllContent({bool forceRefresh = false}) async {
    if (_credentials == null || !_isConnected) return;

    // Falls bereits preloading läuft (von connect() gestartet), nicht nochmal starten
    // Aber wenn wir schon im preloading sind, weitermachen
    final wasAlreadyPreloading = _isPreloading;

    _isPreloading = true;
    _preloadProgress = 0.0;
    _preloadStatus = 'Prüfe Cache...';
    if (!wasAlreadyPreloading) {
      notifyListeners();
    }

    try {
      // Step 1: Check if cache is valid
      if (!forceRefresh && await _cacheService.isCacheValid(_credentials!)) {
        // Load from cache
        _preloadStatus = 'Lade gecachte Inhalte...';
        _preloadProgress = 0.1;
        notifyListeners();

        await _loadFromCache();

        _preloadProgress = 1.0;
        _preloadStatus = 'Fertig';
        notifyListeners();

        debugPrint('Content loaded from cache');
      } else {
        // Fetch fresh data and cache it
        await _fetchAndCacheAllContent();
      }
    } catch (e) {
      debugPrint('Preload error: $e');
      _preloadStatus = 'Fehler beim Laden';
    } finally {
      _isPreloading = false;
      notifyListeners();
    }
  }

  /// Lädt alle Inhalte aus dem Cache
  Future<void> _loadFromCache() async {
    _preloadStatus = 'Lade Startseite...';
    _preloadProgress = 0.2;
    notifyListeners();

    _startScreenContent = await _cacheService.loadStartScreenContent();
    debugPrint('Cache: StartScreen loaded - ${_startScreenContent?.curatedMovies.length ?? 0} curated movies');

    _preloadStatus = 'Lade Filme...';
    _preloadProgress = 0.4;
    notifyListeners();

    _moviesScreenContent = await _cacheService.loadMoviesScreenContent();
    debugPrint('Cache: MoviesScreen loaded - ${_moviesScreenContent?.categories.length ?? 0} categories');

    _preloadStatus = 'Lade Serien...';
    _preloadProgress = 0.6;
    notifyListeners();

    _seriesScreenContent = await _cacheService.loadSeriesScreenContent();
    debugPrint('Cache: SeriesScreen loaded - ${_seriesScreenContent?.categories.length ?? 0} categories');

    _preloadStatus = 'Lade Live TV...';
    _preloadProgress = 0.8;
    notifyListeners();

    _liveTvScreenContent = await _cacheService.loadLiveTvScreenContent();
    debugPrint('Cache: LiveTvScreen loaded - ${_liveTvScreenContent?.categories.length ?? 0} categories');
  }

  /// Lädt alle Inhalte von der API und cached sie
  Future<void> _fetchAndCacheAllContent() async {
    // Step 1: Load raw data (40%)
    _preloadStatus = 'Lade Filme...';
    _preloadProgress = 0.05;
    notifyListeners();

    final allMovies = await getMovies();
    _preloadProgress = 0.15;
    notifyListeners();

    _preloadStatus = 'Lade Serien...';
    final allSeries = await getSeries();
    _preloadProgress = 0.25;
    notifyListeners();

    _preloadStatus = 'Lade Live TV...';
    final allStreams = await getLiveStreams();
    _preloadProgress = 0.35;
    notifyListeners();

    // Step 2: Process screen content (50%)
    _preloadStatus = 'Verarbeite Inhalte...';
    notifyListeners();

    // Process all screen content
    _startScreenContent = await _buildStartScreenContentInternal(allMovies, allSeries);
    _preloadProgress = 0.50;
    notifyListeners();

    _moviesScreenContent = await compute(_buildMoviesScreenContent, allMovies);
    _preloadProgress = 0.60;
    notifyListeners();

    _seriesScreenContent = await compute(_buildSeriesScreenContent, allSeries);
    _preloadProgress = 0.70;
    notifyListeners();

    _liveTvScreenContent = await compute(_buildLiveTvScreenContent, allStreams);
    _preloadProgress = 0.80;
    notifyListeners();

    // Step 3: Save to cache (20%)
    _preloadStatus = 'Speichere Cache...';
    notifyListeners();

    await _cacheService.saveStartScreenContent(_startScreenContent!, _credentials!);
    _preloadProgress = 0.85;
    notifyListeners();

    await _cacheService.saveMoviesScreenContent(_moviesScreenContent!, _credentials!);
    _preloadProgress = 0.90;
    notifyListeners();

    await _cacheService.saveSeriesScreenContent(_seriesScreenContent!, _credentials!);
    _preloadProgress = 0.95;
    notifyListeners();

    await _cacheService.saveLiveTvScreenContent(_liveTvScreenContent!, _credentials!);
    _preloadProgress = 1.0;
    _preloadStatus = 'Fertig';
    notifyListeners();

    debugPrint('Content fetched, processed and cached');
  }

  /// Interne Methode zum Aufbauen des StartScreen-Contents (ohne Caching-Logik)
  Future<StartScreenContent> _buildStartScreenContentInternal(
    List<XTremeCodeVodItem> allMovies,
    List<XTremeCodeSeriesItem> allSeries,
  ) async {
    // Find popular content using compute for heavy parsing
    final popularMovies = await compute(_filterPopularMovies, allMovies);
    final popularSeries = await compute(_filterPopularSeries, allSeries);

    // Find curated content
    final curatedMovies = await compute(_filterCuratedMovies, allMovies);
    final curatedSeries = await compute(_filterCuratedSeries, allSeries);
    final curatedKids = await compute(_filterCuratedKids, _CuratedKidsParams(allMovies, allSeries));

    // Find thematic content
    final thrillerSeries = await compute(_filterThrillerSeries, allSeries);
    final actionMovies = await compute(_filterActionMovies, allMovies);

    // Find spotlight content for hero banner
    final spotlight = _selectDailySpotlight(curatedMovies, curatedSeries, allMovies, allSeries);

    // Generate daily section order
    final sectionOrder = _getDailySectionOrder();

    return StartScreenContent(
      popularMovies: popularMovies.take(20).toList(),
      popularSeries: popularSeries.take(20).toList(),
      spotlight: spotlight,
      curatedMovies: curatedMovies.take(25).toList(),
      curatedSeries: curatedSeries.take(25).toList(),
      curatedKids: curatedKids.take(20).toList(),
      thrillerSeries: thrillerSeries.take(20).toList(),
      actionMovies: actionMovies.take(20).toList(),
      allMovies: [], // Wird bei Bedarf über "Alle Inhalte" geladen
      allSeries: [], // Wird bei Bedarf über "Alle Inhalte" geladen
      sectionOrder: sectionOrder,
    );
  }

  /// Invalidiert den Cache und erzwingt ein Neuladen
  Future<void> refreshAllContent() async {
    await _cacheService.clearCache();
    await preloadAllContent(forceRefresh: true);
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

  /// Setzt den Buffer-Modus für den Video-Player
  Future<void> setBufferMode(String mode) async {
    if (mode != 'live' && mode != 'balanced' && mode != 'stable') {
      debugPrint('Invalid buffer mode: $mode');
      return;
    }
    _bufferMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('player_buffer_mode', mode);
    notifyListeners();
    debugPrint('Buffer mode set to: $mode');
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

  // ==================== Favoriten ====================

  /// Lädt die gespeicherten Favoriten
  Future<void> _loadFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('favorites');
      if (json != null) {
        _favorites = Favorite.decodeList(json);
        debugPrint('Loaded ${_favorites.length} favorites');
      }
    } catch (e) {
      debugPrint('Error loading favorites: $e');
      _favorites = [];
    }
  }

  /// Speichert die Favoriten
  Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('favorites', Favorite.encodeList(_favorites));
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
  }

  /// Fügt einen Favoriten hinzu
  Future<void> addFavorite(Favorite favorite) async {
    if (!_favorites.any((f) => f.id == favorite.id)) {
      _favorites.add(favorite);
      await _saveFavorites();
      notifyListeners();
    }
  }

  /// Entfernt einen Favoriten
  Future<void> removeFavorite(String id) async {
    _favorites.removeWhere((f) => f.id == id);
    await _saveFavorites();
    notifyListeners();
  }

  /// Prüft ob ein Item ein Favorit ist
  bool isFavorite(String id) {
    return _favorites.any((f) => f.id == id);
  }

  /// Toggle: Fügt hinzu oder entfernt Favorit
  Future<void> toggleFavorite(Favorite favorite) async {
    if (isFavorite(favorite.id)) {
      await removeFavorite(favorite.id);
    } else {
      await addFavorite(favorite);
    }
  }

  /// Löscht alle Favoriten
  Future<void> clearAllFavorites() async {
    _favorites.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('favorites');
    notifyListeners();
  }

  // ==================== Suchhistorie ====================

  /// Lädt die gespeicherte Suchhistorie
  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _searchHistory = prefs.getStringList('search_history') ?? [];
      debugPrint('Loaded ${_searchHistory.length} search history entries');
    } catch (e) {
      debugPrint('Error loading search history: $e');
      _searchHistory = [];
    }
  }

  /// Speichert die Suchhistorie
  Future<void> _saveSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('search_history', _searchHistory);
    } catch (e) {
      debugPrint('Error saving search history: $e');
    }
  }

  /// Fügt einen Suchbegriff zur Historie hinzu (max 5 Einträge)
  Future<void> addToSearchHistory(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return;

    // Entferne den Begriff falls er schon existiert (um ihn nach oben zu verschieben)
    _searchHistory.remove(trimmed);

    // Füge am Anfang hinzu
    _searchHistory.insert(0, trimmed);

    // Beschränke auf 5 Einträge
    if (_searchHistory.length > 5) {
      _searchHistory = _searchHistory.take(5).toList();
    }

    await _saveSearchHistory();
    notifyListeners();
  }

  /// Entfernt einen einzelnen Eintrag aus der Suchhistorie
  Future<void> removeFromSearchHistory(String query) async {
    _searchHistory.remove(query);
    await _saveSearchHistory();
    notifyListeners();
  }

  /// Löscht die gesamte Suchhistorie
  Future<void> clearSearchHistory() async {
    _searchHistory.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('search_history');
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
  /// Wenn Content bereits vorgeladen ist, wird dieser sofort zurückgegeben
  Future<StartScreenContent> loadStartScreenContent({bool forceRefresh = false}) async {
    // Return cached content if available (from preload)
    if (_startScreenContent != null && !forceRefresh) {
      // Falls aus Cache geladen und allMovies/allSeries leer sind, lade sie nach
      if (_startScreenContent!.allMovies.isEmpty || _startScreenContent!.allSeries.isEmpty) {
        await _fillStartScreenAllContent();
      }
      return _startScreenContent!;
    }

    // Wait for preloading if in progress
    if (_isPreloading) {
      while (_isPreloading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (_startScreenContent != null) {
        if (_startScreenContent!.allMovies.isEmpty || _startScreenContent!.allSeries.isEmpty) {
          await _fillStartScreenAllContent();
        }
        return _startScreenContent!;
      }
    }

    // Prevent multiple simultaneous loads
    if (_isLoadingStartScreen) {
      while (_isLoadingStartScreen) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _startScreenContent ?? StartScreenContent.empty();
    }

    // Fallback: Load manually if preload didn't happen
    _isLoadingStartScreen = true;
    notifyListeners();

    try {
      final allMovies = await getMovies();
      final allSeries = await getSeries();
      _startScreenContent = await _buildStartScreenContentInternal(allMovies, allSeries);
      // Fülle auch allMovies/allSeries
      final sortedMovies = await compute(_sortAlphabetically, allMovies);
      final sortedSeries = await compute(_sortSeriesAlphabetically, allSeries);
      _startScreenContent = StartScreenContent(
        popularMovies: _startScreenContent!.popularMovies,
        popularSeries: _startScreenContent!.popularSeries,
        spotlight: _startScreenContent!.spotlight,
        curatedMovies: _startScreenContent!.curatedMovies,
        curatedSeries: _startScreenContent!.curatedSeries,
        curatedKids: _startScreenContent!.curatedKids,
        thrillerSeries: _startScreenContent!.thrillerSeries,
        actionMovies: _startScreenContent!.actionMovies,
        allMovies: sortedMovies,
        allSeries: sortedSeries,
        sectionOrder: _startScreenContent!.sectionOrder,
      );
      debugPrint('Start screen content loaded manually');
    } catch (e) {
      debugPrint('Error loading start screen content: $e');
      _startScreenContent = StartScreenContent.empty();
    }

    _isLoadingStartScreen = false;
    notifyListeners();

    return _startScreenContent!;
  }

  /// Füllt allMovies/allSeries nach, wenn aus Cache geladen
  Future<void> _fillStartScreenAllContent() async {
    if (_startScreenContent == null) return;
    final allMovies = await getMovies();
    final allSeries = await getSeries();
    final sortedMovies = await compute(_sortAlphabetically, allMovies);
    final sortedSeries = await compute(_sortSeriesAlphabetically, allSeries);
    _startScreenContent = StartScreenContent(
      popularMovies: _startScreenContent!.popularMovies,
      popularSeries: _startScreenContent!.popularSeries,
      spotlight: _startScreenContent!.spotlight,
      curatedMovies: _startScreenContent!.curatedMovies,
      curatedSeries: _startScreenContent!.curatedSeries,
      curatedKids: _startScreenContent!.curatedKids,
      thrillerSeries: _startScreenContent!.thrillerSeries,
      actionMovies: _startScreenContent!.actionMovies,
      allMovies: sortedMovies,
      allSeries: sortedSeries,
      sectionOrder: _startScreenContent!.sectionOrder,
    );
  }

  /// Lädt alle Filme für "Alle Inhalte" Ansicht (on-demand, nicht gecacht)
  Future<List<XTremeCodeVodItem>> loadAllMoviesSorted() async {
    final allMovies = await getMovies();
    return compute(_sortAlphabetically, allMovies);
  }

  /// Lädt alle Serien für "Alle Inhalte" Ansicht (on-demand, nicht gecacht)
  Future<List<XTremeCodeSeriesItem>> loadAllSeriesSorted() async {
    final allSeries = await getSeries();
    return compute(_sortSeriesAlphabetically, allSeries);
  }

  /// Wählt den täglichen Spotlight-Inhalt aus
  SpotlightContent? _selectDailySpotlight(
    List<XTremeCodeVodItem> curatedMovies,
    List<XTremeCodeSeriesItem> curatedSeries,
    List<XTremeCodeVodItem> allMovies,
    List<XTremeCodeSeriesItem> allSeries,
  ) {
    // Sammle alle Spotlight-fähigen Inhalte
    final spotlightCandidates = <_SpotlightCandidate>[];

    for (final movie in curatedMovies) {
      final meta = ContentParser.parse(movie.name ?? '');
      if (meta.isSpotlightEligible) {
        spotlightCandidates.add(_SpotlightCandidate(
          item: movie,
          isMovie: true,
          metadata: meta,
        ));
      }
    }

    for (final series in curatedSeries) {
      final meta = ContentParser.parse(series.name ?? '');
      if (meta.isSpotlightEligible) {
        spotlightCandidates.add(_SpotlightCandidate(
          item: series,
          isMovie: false,
          metadata: meta,
        ));
      }
    }

    if (spotlightCandidates.isEmpty) {
      // Fallback: Nimm irgendeinen kuratierten Titel
      if (curatedMovies.isNotEmpty) {
        final movie = curatedMovies.first;
        final meta = ContentParser.parse(movie.name ?? '');
        if (meta.curatedMatch != null) {
          return SpotlightContent(
            name: meta.cleanName,
            imageUrl: movie.streamIcon,
            quality: meta.quality,
            language: meta.language,
            curatedTitle: meta.curatedMatch!,
            isMovie: true,
            originalItem: movie,
          );
        }
      }
      if (curatedSeries.isNotEmpty) {
        final series = curatedSeries.first;
        final meta = ContentParser.parse(series.name ?? '');
        if (meta.curatedMatch != null) {
          return SpotlightContent(
            name: meta.cleanName,
            imageUrl: series.cover,
            quality: meta.quality,
            language: meta.language,
            curatedTitle: meta.curatedMatch!,
            isMovie: false,
            originalItem: series,
          );
        }
      }
      // Absoluter Fallback: 4K Film wenn verfügbar
      for (final movie in allMovies) {
        final meta = ContentParser.parse(movie.name ?? '');
        if (meta.quality == '4K') {
          return SpotlightContent(
            name: meta.cleanName,
            imageUrl: movie.streamIcon,
            quality: meta.quality,
            language: meta.language,
            curatedTitle: CuratedTitle(meta.cleanName, CuratedCategory.movie),
            isMovie: true,
            originalItem: movie,
          );
        }
      }
      return null;
    }

    // Wähle basierend auf Tag des Jahres (konsistent pro Tag)
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    final index = dayOfYear % spotlightCandidates.length;
    final selected = spotlightCandidates[index];

    if (selected.isMovie) {
      final movie = selected.item as XTremeCodeVodItem;
      return SpotlightContent(
        name: selected.metadata.cleanName,
        imageUrl: movie.streamIcon,
        quality: selected.metadata.quality,
        language: selected.metadata.language,
        curatedTitle: selected.metadata.curatedMatch!,
        isMovie: true,
        originalItem: movie,
      );
    } else {
      final series = selected.item as XTremeCodeSeriesItem;
      return SpotlightContent(
        name: selected.metadata.cleanName,
        imageUrl: series.cover,
        quality: selected.metadata.quality,
        language: selected.metadata.language,
        curatedTitle: selected.metadata.curatedMatch!,
        isMovie: false,
        originalItem: series,
      );
    }
  }

  /// Generiert die tägliche Section-Reihenfolge
  List<StartScreenSection> _getDailySectionOrder() {
    // Feste Sections oben - "Das gefällt dir bestimmt" immer zuerst nach Hero
    final fixedSections = [
      StartScreenSection.curatedPopular,
      StartScreenSection.continueWatching,
      StartScreenSection.favorites,
    ];

    // Sections die geshuffled werden (ohne "Alle" - die kommen immer am Ende)
    final shuffleableSections = [
      StartScreenSection.curatedKids,
      StartScreenSection.thrillerSeries,
      StartScreenSection.actionMovies,
    ];

    // Feste Sections am Ende
    final endSections = [
      StartScreenSection.allMovies,
      StartScreenSection.allSeries,
    ];

    // Seed basierend auf Tag (konsistent pro Tag)
    final now = DateTime.now();
    final seed = now.day + now.month * 31 + now.year * 365;
    final random = Random(seed);
    shuffleableSections.shuffle(random);

    return [...fixedSections, ...shuffleableSections, ...endSections];
  }

  /// Invalidiert den Start Screen Cache
  void invalidateStartScreenCache() {
    _startScreenContent = null;
    notifyListeners();
  }

  // ==================== Movies Screen Content ====================

  /// Lädt den Content für den Movies Screen (gecacht)
  /// Wenn Content bereits vorgeladen ist, wird dieser sofort zurückgegeben
  Future<MoviesScreenContent> loadMoviesScreenContent({bool forceRefresh = false}) async {
    // Return cached content if available (from preload)
    if (_moviesScreenContent != null && !forceRefresh) {
      // Falls aus Cache geladen und allMoviesSorted leer ist, lade sie nach
      if (_moviesScreenContent!.allMoviesSorted.isEmpty) {
        await _fillMoviesAllSorted();
      }
      return _moviesScreenContent!;
    }

    // Wait for preloading if in progress
    if (_isPreloading) {
      while (_isPreloading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (_moviesScreenContent != null) {
        if (_moviesScreenContent!.allMoviesSorted.isEmpty) {
          await _fillMoviesAllSorted();
        }
        return _moviesScreenContent!;
      }
    }

    // Prevent multiple simultaneous loads
    if (_isLoadingMovies) {
      while (_isLoadingMovies) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _moviesScreenContent ?? MoviesScreenContent.empty();
    }

    // Fallback: Load manually if preload didn't happen
    _isLoadingMovies = true;
    notifyListeners();

    try {
      final allMovies = await getMovies();
      _moviesScreenContent = await compute(_buildMoviesScreenContent, allMovies);
      debugPrint('Movies screen content loaded manually');
    } catch (e) {
      debugPrint('Error loading movies screen content: $e');
      _moviesScreenContent = MoviesScreenContent.empty();
    }

    _isLoadingMovies = false;
    notifyListeners();

    return _moviesScreenContent!;
  }

  /// Füllt allMoviesSorted nach, wenn aus Cache geladen
  Future<void> _fillMoviesAllSorted() async {
    if (_moviesScreenContent == null) return;
    final allMovies = await getMovies();
    final sortedMovies = await compute(_sortAlphabetically, allMovies);
    _moviesScreenContent = MoviesScreenContent(
      categories: _moviesScreenContent!.categories,
      allMoviesSorted: sortedMovies,
    );
    notifyListeners();
  }

  // ==================== Series Screen Content ====================

  /// Lädt den Content für den Series Screen (gecacht)
  /// Wenn Content bereits vorgeladen ist, wird dieser sofort zurückgegeben
  Future<SeriesScreenContent> loadSeriesScreenContent({bool forceRefresh = false}) async {
    // Return cached content if available (from preload)
    if (_seriesScreenContent != null && !forceRefresh) {
      // Falls aus Cache geladen und allSeriesSorted leer ist, lade sie nach
      if (_seriesScreenContent!.allSeriesSorted.isEmpty) {
        await _fillSeriesAllSorted();
      }
      return _seriesScreenContent!;
    }

    // Wait for preloading if in progress
    if (_isPreloading) {
      while (_isPreloading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (_seriesScreenContent != null) {
        if (_seriesScreenContent!.allSeriesSorted.isEmpty) {
          await _fillSeriesAllSorted();
        }
        return _seriesScreenContent!;
      }
    }

    // Prevent multiple simultaneous loads
    if (_isLoadingSeries) {
      while (_isLoadingSeries) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _seriesScreenContent ?? SeriesScreenContent.empty();
    }

    // Fallback: Load manually if preload didn't happen
    _isLoadingSeries = true;
    notifyListeners();

    try {
      final allSeries = await getSeries();
      _seriesScreenContent = await compute(_buildSeriesScreenContent, allSeries);
      debugPrint('Series screen content loaded manually');
    } catch (e) {
      debugPrint('Error loading series screen content: $e');
      _seriesScreenContent = SeriesScreenContent.empty();
    }

    _isLoadingSeries = false;
    notifyListeners();

    return _seriesScreenContent!;
  }

  /// Füllt allSeriesSorted nach, wenn aus Cache geladen
  Future<void> _fillSeriesAllSorted() async {
    if (_seriesScreenContent == null) return;
    final allSeries = await getSeries();
    final sortedSeries = await compute(_sortSeriesAlphabetically, allSeries);
    _seriesScreenContent = SeriesScreenContent(
      categories: _seriesScreenContent!.categories,
      allSeriesSorted: sortedSeries,
    );
    notifyListeners();
  }

  // ==================== Live TV Screen Content ====================

  /// Lädt den Content für den Live TV Screen (gecacht)
  /// Wenn Content bereits vorgeladen ist, wird dieser sofort zurückgegeben
  Future<LiveTvScreenContent> loadLiveTvScreenContent({bool forceRefresh = false}) async {
    // Return cached content if available (from preload)
    if (_liveTvScreenContent != null && !forceRefresh) {
      // Falls aus Cache geladen und allStreamsSorted leer ist, lade sie nach
      if (_liveTvScreenContent!.allStreamsSorted.isEmpty) {
        await _fillLiveTvAllSorted();
      }
      return _liveTvScreenContent!;
    }

    // Wait for preloading if in progress
    if (_isPreloading) {
      while (_isPreloading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      if (_liveTvScreenContent != null) {
        if (_liveTvScreenContent!.allStreamsSorted.isEmpty) {
          await _fillLiveTvAllSorted();
        }
        return _liveTvScreenContent!;
      }
    }

    // Prevent multiple simultaneous loads
    if (_isLoadingLiveTv) {
      while (_isLoadingLiveTv) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _liveTvScreenContent ?? LiveTvScreenContent.empty();
    }

    // Fallback: Load manually if preload didn't happen
    _isLoadingLiveTv = true;
    notifyListeners();

    try {
      final allStreams = await getLiveStreams();
      _liveTvScreenContent = await compute(_buildLiveTvScreenContent, allStreams);
      debugPrint('Live TV screen content loaded manually');
    } catch (e) {
      debugPrint('Error loading live TV screen content: $e');
      _liveTvScreenContent = LiveTvScreenContent.empty();
    }

    _isLoadingLiveTv = false;
    notifyListeners();

    return _liveTvScreenContent!;
  }

  /// Füllt allStreamsSorted nach, wenn aus Cache geladen
  Future<void> _fillLiveTvAllSorted() async {
    if (_liveTvScreenContent == null) return;
    final allStreams = await getLiveStreams();
    final sortedStreams = await compute(_sortLiveStreamsAlphabetically, allStreams);
    _liveTvScreenContent = LiveTvScreenContent(
      categories: _liveTvScreenContent!.categories,
      allStreamsSorted: sortedStreams,
    );
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

/// Typen von Sections die auf der Startseite angezeigt werden können
enum StartScreenSection {
  continueWatching,
  favorites,
  curatedPopular,
  curatedKids,
  thrillerSeries,
  actionMovies,
  allMovies,
  allSeries,
}

/// Spotlight-Inhalt für das Hero-Banner
class SpotlightContent {
  final String name;
  final String? imageUrl;
  final String? quality;
  final String? language;
  final CuratedTitle curatedTitle;
  final bool isMovie; // true = Film, false = Serie
  final dynamic originalItem; // XTremeCodeVodItem oder XTremeCodeSeriesItem

  SpotlightContent({
    required this.name,
    this.imageUrl,
    this.quality,
    this.language,
    required this.curatedTitle,
    required this.isMovie,
    required this.originalItem,
  });
}

class StartScreenContent {
  final List<XTremeCodeVodItem> popularMovies;
  final List<XTremeCodeSeriesItem> popularSeries;

  /// Spotlight für Hero-Banner
  final SpotlightContent? spotlight;

  /// Kuratierte beliebte Filme
  final List<XTremeCodeVodItem> curatedMovies;

  /// Kuratierte beliebte Serien
  final List<XTremeCodeSeriesItem> curatedSeries;

  /// Kuratierte Kinderinhalte (Filme + Serien gemischt)
  final List<dynamic> curatedKids;

  /// Spannende Serien (Thriller, Crime, Drama)
  final List<XTremeCodeSeriesItem> thrillerSeries;

  /// Action Filme
  final List<XTremeCodeVodItem> actionMovies;

  /// Alle Filme (alphabetisch sortiert)
  final List<XTremeCodeVodItem> allMovies;

  /// Alle Serien (alphabetisch sortiert)
  final List<XTremeCodeSeriesItem> allSeries;

  /// Dynamische Section-Reihenfolge für heute
  final List<StartScreenSection> sectionOrder;

  StartScreenContent({
    required this.popularMovies,
    required this.popularSeries,
    this.spotlight,
    this.curatedMovies = const [],
    this.curatedSeries = const [],
    this.curatedKids = const [],
    this.thrillerSeries = const [],
    this.actionMovies = const [],
    this.allMovies = const [],
    this.allSeries = const [],
    this.sectionOrder = const [],
  });

  factory StartScreenContent.empty() => StartScreenContent(
        popularMovies: [],
        popularSeries: [],
        curatedMovies: [],
        curatedSeries: [],
        curatedKids: [],
        thrillerSeries: [],
        actionMovies: [],
        allMovies: [],
        allSeries: [],
        sectionOrder: [],
      );

  bool get isEmpty =>
      popularMovies.isEmpty &&
      popularSeries.isEmpty &&
      curatedMovies.isEmpty &&
      curatedSeries.isEmpty;

  /// Alle kuratierten Inhalte (Filme + Serien)
  List<dynamic> get allCurated => [...curatedMovies, ...curatedSeries];
}

// Helper class for isolate parameters
class _SortParams<T> {
  final List<T> items;
  final String language;

  _SortParams(this.items, this.language);
}

// ============== OPTIMIERTE Isolate-Funktionen für Start Screen ==============
// Verwenden Quick-Filter ohne volles Parsing für bessere Performance

List<XTremeCodeVodItem> _filterPopularMovies(List<XTremeCodeVodItem> movies) {
  // Optimiert: Quick-Filter statt volles Parsing
  return movies.where((m) {
    return ContentParser.isPopularQuick(m.name ?? '');
  }).toList();
}

List<XTremeCodeSeriesItem> _filterPopularSeries(List<XTremeCodeSeriesItem> series) {
  // Optimiert: Quick-Filter statt volles Parsing
  return series.where((s) {
    return ContentParser.isPopularQuick(s.name ?? '');
  }).toList();
}

// ==================== Curated Content Filtering ====================

/// Helper class für Spotlight-Kandidaten
class _SpotlightCandidate {
  final dynamic item;
  final bool isMovie;
  final ContentMetadata metadata;

  _SpotlightCandidate({
    required this.item,
    required this.isMovie,
    required this.metadata,
  });
}

/// Helper class für Curated Kids Filtering
class _CuratedKidsParams {
  final List<XTremeCodeVodItem> movies;
  final List<XTremeCodeSeriesItem> series;

  _CuratedKidsParams(this.movies, this.series);
}

/// Filtert kuratierte Filme (bekannte Titel)
List<XTremeCodeVodItem> _filterCuratedMovies(List<XTremeCodeVodItem> movies) {
  final result = <XTremeCodeVodItem>[];

  for (final movie in movies) {
    final meta = ContentParser.parse(movie.name ?? '');
    if (meta.isCurated &&
        (meta.curatedMatch!.category == CuratedCategory.movie ||
         meta.curatedMatch!.category == CuratedCategory.documentary)) {
      result.add(movie);
      if (result.length >= 50) break; // Limit für Performance
    }
  }

  // Sortiere nach Match-Score (beste zuerst)
  result.sort((a, b) {
    final metaA = ContentParser.parse(a.name ?? '');
    final metaB = ContentParser.parse(b.name ?? '');
    return metaB.curatedMatchScore.compareTo(metaA.curatedMatchScore);
  });

  return result;
}

/// Filtert kuratierte Serien (bekannte Titel)
List<XTremeCodeSeriesItem> _filterCuratedSeries(List<XTremeCodeSeriesItem> series) {
  final result = <XTremeCodeSeriesItem>[];

  for (final s in series) {
    final meta = ContentParser.parse(s.name ?? '');
    if (meta.isCurated && meta.curatedMatch!.category == CuratedCategory.series) {
      result.add(s);
      if (result.length >= 50) break; // Limit für Performance
    }
  }

  // Sortiere nach Match-Score (beste zuerst)
  result.sort((a, b) {
    final metaA = ContentParser.parse(a.name ?? '');
    final metaB = ContentParser.parse(b.name ?? '');
    return metaB.curatedMatchScore.compareTo(metaA.curatedMatchScore);
  });

  return result;
}

/// Filtert kuratierte Kinderinhalte (Filme + Serien)
List<dynamic> _filterCuratedKids(_CuratedKidsParams params) {
  final result = <dynamic>[];

  // Filme durchsuchen
  for (final movie in params.movies) {
    final meta = ContentParser.parse(movie.name ?? '');
    if (meta.isCurated && meta.curatedMatch!.category == CuratedCategory.kids) {
      result.add(movie);
    }
  }

  // Serien durchsuchen
  for (final series in params.series) {
    final meta = ContentParser.parse(series.name ?? '');
    if (meta.isCurated && meta.curatedMatch!.category == CuratedCategory.kids) {
      result.add(series);
    }
  }

  // Sortiere nach Match-Score
  result.sort((a, b) {
    final nameA = a is XTremeCodeVodItem ? a.name : (a as XTremeCodeSeriesItem).name;
    final nameB = b is XTremeCodeVodItem ? b.name : (b as XTremeCodeSeriesItem).name;
    final metaA = ContentParser.parse(nameA ?? '');
    final metaB = ContentParser.parse(nameB ?? '');
    return metaB.curatedMatchScore.compareTo(metaA.curatedMatchScore);
  });

  return result.take(30).toList();
}

/// Filtert spannende Serien (Thriller, Crime, Drama) basierend auf bekannten Titeln
List<XTremeCodeSeriesItem> _filterThrillerSeries(List<XTremeCodeSeriesItem> series) {
  // Liste bekannter spannender Serien
  const thrillerTitles = [
    'breaking bad', 'better call saul', 'ozark', 'narcos', 'money heist',
    'casa de papel', 'haus des geldes', 'dark', 'squid game', 'mindhunter',
    'true detective', 'fargo', 'the wire', 'dexter', 'hannibal',
    'sherlock', 'homeland', 'prison break', 'the boys', 'peaky blinders',
    'you', 'killing eve', 'the sinner', 'the fall', 'mare of easttown',
    'mare', 'yellowjackets', 'severance', 'the night of', 'big little lies',
    'sharp objects', 'the undoing', 'the outsider', 'from', 'the last of us',
    'chernobyl', 'band of brothers', 'the americans', 'the blacklist',
    'person of interest', 'mr robot', 'westworld', 'lost', 'the 100',
    'the walking dead', 'fear the walking dead', 'vikings',
  ];

  final result = <XTremeCodeSeriesItem>[];

  for (final s in series) {
    final name = s.name?.toLowerCase() ?? '';
    for (final title in thrillerTitles) {
      if (name.contains(title)) {
        result.add(s);
        break;
      }
    }
    if (result.length >= 30) break;
  }

  return result;
}

/// Filtert Action-Filme basierend auf bekannten Titeln
List<XTremeCodeVodItem> _filterActionMovies(List<XTremeCodeVodItem> movies) {
  // Liste bekannter Action-Filme
  const actionTitles = [
    'john wick', 'fast', 'furious', 'mission impossible', 'top gun',
    'mad max', 'die hard', 'terminator', 'predator', 'rambo',
    'expendables', 'taken', 'matrix', 'batman', 'dark knight',
    'avengers', 'iron man', 'thor', 'captain america', 'black panther',
    'spider-man', 'spider man', 'deadpool', 'wolverine', 'x-men',
    'transformers', 'pacific rim', 'godzilla', 'kong', 'jurassic',
    'indiana jones', 'james bond', '007', 'bourne', 'jack reacher',
    'equalizer', 'nobody', 'bullet train', 'extraction', 'tyler rake',
    'raid', 'old guard', 'gray man', 'fall guy', 'furiosa',
    'rebel moon', 'civil war', 'twisters',
  ];

  final result = <XTremeCodeVodItem>[];

  for (final m in movies) {
    final name = m.name?.toLowerCase() ?? '';
    for (final title in actionTitles) {
      if (name.contains(title)) {
        result.add(m);
        break;
      }
    }
    if (result.length >= 30) break;
  }

  return result;
}

/// Sortiert Filme alphabetisch
List<XTremeCodeVodItem> _sortAlphabetically(List<XTremeCodeVodItem> movies) {
  final sorted = List<XTremeCodeVodItem>.from(movies);
  sorted.sort((a, b) {
    final nameA = ContentParser.parse(a.name ?? '').cleanName.toLowerCase();
    final nameB = ContentParser.parse(b.name ?? '').cleanName.toLowerCase();
    return nameA.compareTo(nameB);
  });
  return sorted;
}

/// Sortiert Serien alphabetisch
List<XTremeCodeSeriesItem> _sortSeriesAlphabetically(List<XTremeCodeSeriesItem> series) {
  final sorted = List<XTremeCodeSeriesItem>.from(series);
  sorted.sort((a, b) {
    final nameA = ContentParser.parse(a.name ?? '').cleanName.toLowerCase();
    final nameB = ContentParser.parse(b.name ?? '').cleanName.toLowerCase();
    return nameA.compareTo(nameB);
  });
  return sorted;
}

/// Sortiert Live-Streams alphabetisch
List<XTremeCodeLiveStreamItem> _sortLiveStreamsAlphabetically(List<XTremeCodeLiveStreamItem> streams) {
  final sorted = List<XTremeCodeLiveStreamItem>.from(streams);
  sorted.sort((a, b) {
    final nameA = (a.name ?? '').toLowerCase();
    final nameB = (b.name ?? '').toLowerCase();
    return nameA.compareTo(nameB);
  });
  return sorted;
}

// ==================== Movies Screen Content ====================

class PseudoCategory<T> {
  final String title;
  final String icon;
  final List<T> items;

  PseudoCategory({
    required this.title,
    required this.icon,
    required this.items,
  });
}

class MoviesScreenContent {
  final List<PseudoCategory<XTremeCodeVodItem>> categories;
  final List<XTremeCodeVodItem> allMoviesSorted;

  MoviesScreenContent({
    required this.categories,
    required this.allMoviesSorted,
  });

  factory MoviesScreenContent.empty() => MoviesScreenContent(
        categories: [],
        allMoviesSorted: [],
      );

  // isEmpty prüft categories, nicht allMoviesSorted (das wird on-demand geladen)
  bool get isEmpty => categories.isEmpty;
}

class SeriesScreenContent {
  final List<PseudoCategory<XTremeCodeSeriesItem>> categories;
  final List<XTremeCodeSeriesItem> allSeriesSorted;

  SeriesScreenContent({
    required this.categories,
    required this.allSeriesSorted,
  });

  factory SeriesScreenContent.empty() => SeriesScreenContent(
        categories: [],
        allSeriesSorted: [],
      );

  // isEmpty prüft categories, nicht allSeriesSorted (das wird on-demand geladen)
  bool get isEmpty => categories.isEmpty;
}

class LiveTvScreenContent {
  final List<PseudoCategory<XTremeCodeLiveStreamItem>> categories;
  final List<XTremeCodeLiveStreamItem> allStreamsSorted;

  LiveTvScreenContent({
    required this.categories,
    required this.allStreamsSorted,
  });

  factory LiveTvScreenContent.empty() => LiveTvScreenContent(
        categories: [],
        allStreamsSorted: [],
      );

  // isEmpty prüft categories, nicht allStreamsSorted (das wird on-demand geladen)
  bool get isEmpty => categories.isEmpty;
}

// ============== OPTIMIERTE Isolate-Funktionen ==============
// Verwenden Early-Exit, Quick-Filters und optimierte String-Operationen

/// Hilfsfunktion: Findet bis zu N Items die eine Bedingung erfüllen (Early-Exit)
List<T> _findUpTo<T>(List<T> items, int limit, bool Function(T) test) {
  final result = <T>[];
  for (final item in items) {
    if (test(item)) {
      result.add(item);
      if (result.length >= limit) break;
    }
  }
  return result;
}

/// Hilfsfunktion: Schnelle Keyword-Suche in Name (case-insensitive)
bool _nameContainsAny(String upperName, List<String> keywords) {
  for (final keyword in keywords) {
    if (upperName.contains(keyword)) return true;
  }
  return false;
}

MoviesScreenContent _buildMoviesScreenContent(List<XTremeCodeVodItem> allMovies) {
  final categories = <PseudoCategory<XTremeCodeVodItem>>[];
  const limit = 20;

  // 1. 4K Filme - Quick-Filter mit Early-Exit
  final movies4k = _findUpTo(allMovies, limit, (m) {
    final quality = ContentParser.getQualityQuick(m.name ?? '');
    return quality == '4K' || quality == '8K';
  });
  if (movies4k.isNotEmpty) {
    categories.add(PseudoCategory(
      title: '4K Filme',
      icon: 'assets/icons/monitor-play.svg',
      items: movies4k,
    ));
  }

  // 3. Deutsche Filme - Quick-Filter mit Early-Exit
  final germanMovies = _findUpTo(allMovies, limit, (m) {
    final lang = ContentParser.getLanguageQuick(m.name ?? '');
    return lang == 'DE';
  });
  if (germanMovies.isNotEmpty) {
    categories.add(PseudoCategory(
      title: 'Deutsche Filme',
      icon: 'assets/icons/film-strip.svg',
      items: germanMovies,
    ));
  }

  // 4. Kinderfilme - Optimiert: einmal toUpperCase, keine Regex
  const kidsKeywords = ['KIDS', 'KINDER', 'ANIMATION', 'DISNEY'];
  final kidsMovies = _findUpTo(allMovies, limit, (m) {
    final upper = (m.name ?? '').toUpperCase();
    return _nameContainsAny(upper, kidsKeywords);
  });
  if (kidsMovies.isNotEmpty) {
    categories.add(PseudoCategory(
      title: 'Kinderfilme',
      icon: 'assets/icons/star.svg',
      items: kidsMovies,
    ));
  }

  // Optimierte alphabetische Sortierung
  final sortedMovies = _sortAlphabetically(allMovies);

  return MoviesScreenContent(
    categories: categories,
    allMoviesSorted: sortedMovies,
  );
}

SeriesScreenContent _buildSeriesScreenContent(List<XTremeCodeSeriesItem> allSeries) {
  final categories = <PseudoCategory<XTremeCodeSeriesItem>>[];
  const limit = 20;

  // 1. 4K Serien - Quick-Filter mit Early-Exit
  final series4k = _findUpTo(allSeries, limit, (s) {
    final quality = ContentParser.getQualityQuick(s.name ?? '');
    return quality == '4K' || quality == '8K';
  });
  if (series4k.isNotEmpty) {
    categories.add(PseudoCategory(
      title: '4K Serien',
      icon: 'assets/icons/monitor-play.svg',
      items: series4k,
    ));
  }

  // 3. Deutsche Serien - Quick-Filter mit Early-Exit
  final germanSeries = _findUpTo(allSeries, limit, (s) {
    final lang = ContentParser.getLanguageQuick(s.name ?? '');
    return lang == 'DE';
  });
  if (germanSeries.isNotEmpty) {
    categories.add(PseudoCategory(
      title: 'Deutsche Serien',
      icon: 'assets/icons/monitor-play.svg',
      items: germanSeries,
    ));
  }

  // 4. Kinderserien - Optimiert: einmal toUpperCase, keine Regex
  const kidsKeywords = ['KIDS', 'KINDER', 'ANIMATION', 'DISNEY', 'CARTOON'];
  final kidsSeries = _findUpTo(allSeries, limit, (s) {
    final upper = (s.name ?? '').toUpperCase();
    return _nameContainsAny(upper, kidsKeywords);
  });
  if (kidsSeries.isNotEmpty) {
    categories.add(PseudoCategory(
      title: 'Kinderserien',
      icon: 'assets/icons/star.svg',
      items: kidsSeries,
    ));
  }

  // Optimierte alphabetische Sortierung
  final sortedSeries = _sortSeriesAlphabetically(allSeries);

  return SeriesScreenContent(
    categories: categories,
    allSeriesSorted: sortedSeries,
  );
}

LiveTvScreenContent _buildLiveTvScreenContent(List<XTremeCodeLiveStreamItem> allStreams) {
  final categories = <PseudoCategory<XTremeCodeLiveStreamItem>>[];
  const limit = 20;

  // 1. Deutsche Sender - Kombinierter Quick-Check
  final germanStreams = _findUpTo(allStreams, limit, (s) {
    final name = s.name ?? '';
    // Quick country check
    final country = ContentParser.getCountryQuick(name);
    if (country == 'DE') return true;
    // Quick language check
    final lang = ContentParser.getLanguageQuick(name);
    if (lang == 'DE') return true;
    // Keyword check
    return name.toUpperCase().contains('GERMAN');
  });
  if (germanStreams.isNotEmpty) {
    categories.add(PseudoCategory(
      title: 'Deutsche Sender',
      icon: 'assets/icons/television.svg',
      items: germanStreams,
    ));
  }

  // 3. Sport - Optimiert: einmal toUpperCase, keine Regex
  const sportKeywords = ['SPORT', 'DAZN', 'SKY SPORT', 'EUROSPORT'];
  final sportStreams = _findUpTo(allStreams, limit, (s) {
    final upper = (s.name ?? '').toUpperCase();
    return _nameContainsAny(upper, sportKeywords);
  });
  if (sportStreams.isNotEmpty) {
    categories.add(PseudoCategory(
      title: 'Sport',
      icon: 'assets/icons/star.svg',
      items: sportStreams,
    ));
  }

  // 4. Nachrichten - Optimiert: einmal toUpperCase, keine Regex
  const newsKeywords = ['NEWS', 'NACHRICHTEN', 'N-TV', 'NTV', 'WELT', 'CNN', 'BBC NEWS'];
  final newsStreams = _findUpTo(allStreams, limit, (s) {
    final upper = (s.name ?? '').toUpperCase();
    return _nameContainsAny(upper, newsKeywords);
  });
  if (newsStreams.isNotEmpty) {
    categories.add(PseudoCategory(
      title: 'Nachrichten',
      icon: 'assets/icons/broadcast.svg',
      items: newsStreams,
    ));
  }

  // Optimierte alphabetische Sortierung
  final sortedStreams = _sortLiveStreamsAlphabetically(allStreams);

  return LiveTvScreenContent(
    categories: categories,
    allStreamsSorted: sortedStreams,
  );
}
