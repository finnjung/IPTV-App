import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download.dart';
import '../models/watch_progress.dart';

class DownloadService extends ChangeNotifier {
  static final DownloadService _instance = DownloadService._internal();
  factory DownloadService() => _instance;
  DownloadService._internal();

  final Dio _dio = Dio(BaseOptions(
    // Simuliere einen Media-Player um Server-Blockaden zu umgehen
    headers: {
      'User-Agent': 'VLC/3.0.20 LibVLC/3.0.20',
      'Accept': '*/*',
      'Accept-Encoding': 'identity',
      'Connection': 'keep-alive',
    },
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 60),
    followRedirects: true,
    maxRedirects: 5,
  ));
  final Map<String, CancelToken> _cancelTokens = {};
  List<Download> _downloads = [];
  bool _isInitialized = false;

  // Maximale gleichzeitige Downloads
  static const int maxConcurrentDownloads = 2;

  List<Download> get downloads => List.unmodifiable(_downloads);

  List<Download> get activeDownloads =>
      _downloads.where((d) => d.isDownloading).toList();

  List<Download> get pendingDownloads =>
      _downloads.where((d) => d.isPending).toList();

  List<Download> get completedDownloads =>
      _downloads.where((d) => d.isCompleted).toList();

  List<Download> get movieDownloads =>
      _downloads.where((d) => d.contentType == ContentType.movie).toList();

  List<Download> get seriesDownloads =>
      _downloads.where((d) => d.contentType == ContentType.series).toList();

  /// Gruppiert Serien-Downloads nach Serie
  Map<int, List<Download>> get seriesDownloadsGrouped {
    final grouped = <int, List<Download>>{};
    for (final download in seriesDownloads) {
      if (download.seriesId != null) {
        grouped.putIfAbsent(download.seriesId!, () => []).add(download);
      }
    }
    // Sortiere Episoden innerhalb jeder Serie
    for (final episodes in grouped.values) {
      episodes.sort((a, b) {
        final seasonCompare = (a.seasonNum ?? 0).compareTo(b.seasonNum ?? 0);
        if (seasonCompare != 0) return seasonCompare;
        return (a.episodeNum ?? 0).compareTo(b.episodeNum ?? 0);
      });
    }
    return grouped;
  }

  /// Initialisiert den Service und lädt gespeicherte Downloads
  Future<void> init() async {
    if (_isInitialized) return;

    await _loadDownloads();
    _isInitialized = true;

    // Starte ausstehende Downloads
    _processQueue();
  }

  /// Lädt die gespeicherten Downloads
  Future<void> _loadDownloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString('downloads');
      if (json != null) {
        _downloads = Download.decodeList(json);

        // Setze downloading/paused Downloads auf pending zurück
        _downloads = _downloads.map((d) {
          if (d.isDownloading || d.isPaused) {
            return d.copyWith(status: DownloadStatus.pending);
          }
          return d;
        }).toList();

        debugPrint('Loaded ${_downloads.length} downloads');
      }
    } catch (e) {
      debugPrint('Error loading downloads: $e');
      _downloads = [];
    }
  }

  /// Speichert die Downloads
  Future<void> _saveDownloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('downloads', Download.encodeList(_downloads));
    } catch (e) {
      debugPrint('Error saving downloads: $e');
    }
  }

  /// Gibt das interne Download-Verzeichnis zurück (nicht sichtbar für User)
  Future<Directory> getDownloadsDirectory() async {
    // ApplicationSupportDirectory ist versteckt und app-spezifisch
    final appDir = await getApplicationSupportDirectory();
    final downloadsDir = Directory('${appDir.path}/offline_content');
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    return downloadsDir;
  }

  /// Gibt den öffentlichen Downloads-Ordner zurück (für Export)
  Future<Directory?> getPublicDownloadsDirectory() async {
    if (Platform.isAndroid) {
      // Android: /storage/emulated/0/Download
      return Directory('/storage/emulated/0/Download');
    } else if (Platform.isIOS) {
      // iOS: Kein öffentlicher Downloads-Ordner
      return null;
    } else {
      // macOS/Windows/Linux: User Downloads folder
      final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
      if (home != null) {
        return Directory('$home/Downloads');
      }
      return null;
    }
  }

  /// Exportiert einen Download in den öffentlichen Downloads-Ordner
  Future<String?> exportDownload(String id) async {
    final download = getDownload(id);
    if (download == null || !download.isCompleted || download.localPath == null) {
      return null;
    }

    final publicDir = await getPublicDownloadsDirectory();
    if (publicDir == null) return null;

    try {
      final sourceFile = File(download.localPath!);
      if (!await sourceFile.exists()) return null;

      // Erstelle sinnvollen Dateinamen
      String filename;
      if (download.contentType == ContentType.movie) {
        filename = '${download.title}.${download.extension ?? 'mp4'}';
      } else {
        filename = '${download.seriesName ?? 'Serie'} - ${download.subtitle ?? download.title}.${download.extension ?? 'mp4'}';
      }

      // Entferne ungültige Zeichen aus Dateinamen
      filename = filename.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

      final targetPath = '${publicDir.path}/$filename';
      await sourceFile.copy(targetPath);

      return targetPath;
    } catch (e) {
      debugPrint('Error exporting download: $e');
      return null;
    }
  }

  /// Berechnet den verfügbaren Speicherplatz (nicht immer verfügbar)
  Future<int> getAvailableStorage() async {
    // Auf den meisten Plattformen nicht direkt verfügbar
    // Könnte mit platform-spezifischen Plugins erweitert werden
    return -1;
  }

  /// Prüft ob ein Download existiert
  bool hasDownload(String id) {
    return _downloads.any((d) => d.id == id);
  }

  /// Holt einen Download anhand der ID
  Download? getDownload(String id) {
    try {
      return _downloads.firstWhere((d) => d.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Prüft ob ein Content heruntergeladen wurde
  bool isDownloaded(String id) {
    final download = getDownload(id);
    return download != null && download.isCompleted;
  }

  /// Gibt den lokalen Pfad für einen Download zurück (falls vorhanden)
  String? getLocalPath(String id) {
    final download = getDownload(id);
    if (download != null && download.isCompleted && download.localPath != null) {
      final file = File(download.localPath!);
      if (file.existsSync()) {
        return download.localPath;
      }
    }
    return null;
  }

  /// Fügt einen Download zur Queue hinzu
  Future<void> addDownload(Download download) async {
    if (hasDownload(download.id)) {
      debugPrint('Download ${download.id} already exists');
      return;
    }

    _downloads.add(download);
    await _saveDownloads();
    notifyListeners();

    // Starte Queue-Verarbeitung
    _processQueue();
  }

  /// Fügt mehrere Downloads hinzu (z.B. ganze Staffel)
  Future<void> addDownloads(List<Download> downloads) async {
    for (final download in downloads) {
      if (!hasDownload(download.id)) {
        _downloads.add(download);
      }
    }
    await _saveDownloads();
    notifyListeners();

    // Starte Queue-Verarbeitung
    _processQueue();
  }

  /// Verarbeitet die Download-Queue
  void _processQueue() {
    final active = activeDownloads.length;
    if (active >= maxConcurrentDownloads) return;

    final pending = pendingDownloads;
    if (pending.isEmpty) return;

    // Starte nächste Downloads bis zum Limit
    final toStart = pending.take(maxConcurrentDownloads - active);
    for (final download in toStart) {
      _startDownload(download);
    }
  }

  /// Startet einen Download
  Future<void> _startDownload(Download download) async {
    final index = _downloads.indexWhere((d) => d.id == download.id);
    if (index == -1) return;

    // Update Status
    _downloads[index] = download.copyWith(status: DownloadStatus.downloading);
    notifyListeners();

    final cancelToken = CancelToken();
    _cancelTokens[download.id] = cancelToken;

    try {
      // Bestimme Dateinamen und Pfad
      final downloadsDir = await getDownloadsDirectory();
      String subDir;
      String filename;

      if (download.contentType == ContentType.movie) {
        subDir = 'movies';
        filename = '${download.id}.${download.extension ?? 'mp4'}';
      } else {
        subDir = 'series/${download.seriesId}';
        filename = 'S${download.seasonNum?.toString().padLeft(2, '0') ?? '00'}'
            'E${download.episodeNum?.toString().padLeft(2, '0') ?? '00'}'
            '.${download.extension ?? 'mp4'}';
      }

      final targetDir = Directory('${downloadsDir.path}/$subDir');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final filePath = '${targetDir.path}/$filename';
      final tempPath = '$filePath.tmp';

      // Prüfe ob temporäre Datei existiert (Resume)
      int startByte = 0;
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        startByte = await tempFile.length();
        debugPrint('Resuming download from byte $startByte');
      }

      // Download starten - immer Range-Request um wie Streaming auszusehen
      final response = await _dio.download(
        download.sourceUrl,
        tempPath,
        cancelToken: cancelToken,
        deleteOnError: false,
        options: Options(
          headers: {
            'Range': 'bytes=$startByte-',
            'Referer': Uri.parse(download.sourceUrl).origin,
          },
          // Accept partial content (206) as success
          validateStatus: (status) => status == 200 || status == 206,
        ),
        onReceiveProgress: (received, total) {
          final actualTotal = total > 0 ? total + startByte : 0;
          final actualReceived = received + startByte;

          _updateDownloadProgress(
            download.id,
            downloadedBytes: actualReceived,
            totalBytes: actualTotal,
          );
        },
      );

      if (response.statusCode == 200 || response.statusCode == 206) {
        // Download erfolgreich - temp zu final umbenennen
        await tempFile.rename(filePath);

        final finalIndex = _downloads.indexWhere((d) => d.id == download.id);
        if (finalIndex != -1) {
          _downloads[finalIndex] = _downloads[finalIndex].copyWith(
            status: DownloadStatus.completed,
            localPath: filePath,
            completedAt: DateTime.now(),
          );
          await _saveDownloads();
          notifyListeners();
        }

        debugPrint('Download completed: ${download.title}');
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        debugPrint('Download cancelled: ${download.title}');
        return;
      }

      final errorIndex = _downloads.indexWhere((d) => d.id == download.id);
      if (errorIndex != -1) {
        _downloads[errorIndex] = _downloads[errorIndex].copyWith(
          status: DownloadStatus.failed,
          errorMessage: _getErrorMessage(e),
        );
        await _saveDownloads();
        notifyListeners();
      }

      debugPrint('Download failed: ${download.title} - ${e.message}');
    } catch (e) {
      final errorIndex = _downloads.indexWhere((d) => d.id == download.id);
      if (errorIndex != -1) {
        _downloads[errorIndex] = _downloads[errorIndex].copyWith(
          status: DownloadStatus.failed,
          errorMessage: e.toString(),
        );
        await _saveDownloads();
        notifyListeners();
      }

      debugPrint('Download error: ${download.title} - $e');
    } finally {
      _cancelTokens.remove(download.id);

      // Nächsten Download starten
      _processQueue();
    }
  }

  /// Aktualisiert den Download-Fortschritt
  void _updateDownloadProgress(
    String id, {
    required int downloadedBytes,
    required int totalBytes,
  }) {
    final index = _downloads.indexWhere((d) => d.id == id);
    if (index == -1) return;

    _downloads[index] = _downloads[index].copyWith(
      downloadedBytes: downloadedBytes,
      totalBytes: totalBytes,
    );
    notifyListeners();
  }

  /// Pausiert einen Download
  Future<void> pauseDownload(String id) async {
    final cancelToken = _cancelTokens[id];
    if (cancelToken != null) {
      cancelToken.cancel('Paused by user');
      _cancelTokens.remove(id);
    }

    final index = _downloads.indexWhere((d) => d.id == id);
    if (index != -1) {
      _downloads[index] = _downloads[index].copyWith(
        status: DownloadStatus.paused,
      );
      await _saveDownloads();
      notifyListeners();
    }
  }

  /// Setzt einen pausierten Download fort
  Future<void> resumeDownload(String id) async {
    final index = _downloads.indexWhere((d) => d.id == id);
    if (index == -1) return;

    final download = _downloads[index];
    if (!download.isPaused && !download.isFailed) return;

    _downloads[index] = download.copyWith(status: DownloadStatus.pending);
    notifyListeners();

    _processQueue();
  }

  /// Bricht einen Download ab und entfernt ihn
  Future<void> cancelDownload(String id) async {
    final cancelToken = _cancelTokens[id];
    if (cancelToken != null) {
      cancelToken.cancel('Cancelled by user');
      _cancelTokens.remove(id);
    }

    await deleteDownload(id);
  }

  /// Löscht einen Download (inkl. Datei)
  Future<void> deleteDownload(String id, {bool deleteFile = true}) async {
    final download = getDownload(id);
    if (download == null) return;

    // Lösche Datei
    if (deleteFile && download.localPath != null) {
      try {
        final file = File(download.localPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error deleting file: $e');
      }

      // Lösche auch temp-Datei
      try {
        final tempFile = File('${download.localPath}.tmp');
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (e) {
        debugPrint('Error deleting temp file: $e');
      }
    }

    _downloads.removeWhere((d) => d.id == id);
    await _saveDownloads();
    notifyListeners();
  }

  /// Löscht alle Downloads einer Serie
  Future<void> deleteSeriesDownloads(int seriesId) async {
    final toDelete = _downloads.where((d) => d.seriesId == seriesId).toList();
    for (final download in toDelete) {
      await deleteDownload(download.id);
    }
  }

  /// Löscht alle abgeschlossenen Downloads
  Future<void> clearCompletedDownloads() async {
    final completed = completedDownloads.toList();
    for (final download in completed) {
      await deleteDownload(download.id);
    }
  }

  /// Berechnet die Gesamtgröße aller Downloads
  int get totalDownloadedBytes {
    return _downloads
        .where((d) => d.isCompleted)
        .fold(0, (sum, d) => sum + d.totalBytes);
  }

  String get formattedTotalSize {
    final bytes = totalDownloadedBytes;
    const gb = 1024 * 1024 * 1024;
    const mb = 1024 * 1024;

    if (bytes >= gb) {
      return '${(bytes / gb).toStringAsFixed(2)} GB';
    } else {
      return '${(bytes / mb).toStringAsFixed(1)} MB';
    }
  }

  /// Hilfsfunktion für Fehlermeldungen
  String _getErrorMessage(DioException e) {
    // Prüfe auf spezifische Status-Codes
    final statusCode = e.response?.statusCode;
    if (statusCode != null) {
      switch (statusCode) {
        case 403:
          return 'Download vom Anbieter nicht erlaubt';
        case 404:
          return 'Inhalt nicht gefunden';
        case 429:
          return 'Zu viele Anfragen - bitte warten';
        case 458:
          return 'Download vom Streaming-Anbieter blockiert';
        case 500:
        case 502:
        case 503:
          return 'Server vorübergehend nicht erreichbar';
      }
      // Andere 4xx Fehler
      if (statusCode >= 400 && statusCode < 500) {
        return 'Download vom Anbieter nicht erlaubt ($statusCode)';
      }
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Zeitüberschreitung';
      case DioExceptionType.connectionError:
        return 'Verbindungsfehler';
      case DioExceptionType.badResponse:
        return 'Server-Fehler ($statusCode)';
      default:
        return e.message ?? 'Unbekannter Fehler';
    }
  }
}
