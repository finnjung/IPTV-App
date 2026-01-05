import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xtream_code_client/xtream_code_client.dart';
import 'cors_proxy_client.dart';

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

  bool get isConnected => _isConnected;
  bool get isLoading => _isLoading;
  String? get error => _error;
  XtreamCredentials? get credentials => _credentials;
  XTremeCodeGeneralInformation? get serverInfo => _serverInfo;

  List<XTremeCodeCategory>? get liveCategories => _liveCategories;
  List<XTremeCodeCategory>? get vodCategories => _vodCategories;
  List<XTremeCodeCategory>? get seriesCategories => _seriesCategories;

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

    if (serverUrl != null && username != null && password != null) {
      _credentials = XtreamCredentials(
        serverUrl: serverUrl,
        port: port ?? '',
        username: username,
        password: password,
        corsProxy: corsProxy,
      );

      await connect(_credentials!);
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

  Future<bool> connect(XtreamCredentials credentials) async {
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
      _seriesByCategory[key] = series;
      return series;
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

    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
